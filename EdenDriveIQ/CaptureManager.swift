import Foundation
import Combine
import ScreenCaptureKit
import CoreMedia
import UIKit

/// Les callbacks de ScreenCaptureKit arrivent hors du MainActor.
private final class PickerEvents: NSObject, SCContentSharingPickerObserver {
    var onSelection: ((SCContentFilter) -> Void)?
    var onCancel: (() -> Void)?
    var onError: ((String) -> Void)?

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        onSelection?(filter)
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        onCancel?()
    }

    func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        onError?(error.localizedDescription)
    }
}

private final class StreamEvents: NSObject, SCStreamDelegate {
    var onStop: ((String) -> Void)?
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        onStop?(error.localizedDescription)
    }
}

@MainActor
final class CaptureManager: ObservableObject {
    @Published private(set) var isCapturing = false
    @Published private(set) var statusText = "Prêt à surveiller Uber/Bolt"
    @Published private(set) var latest: OfferAnalysis?
    @Published private(set) var detectedCount = 0

    private let picker = SCContentSharingPicker.shared
    private let pickerEvents = PickerEvents()
    private let streamEvents = StreamEvents()
    private let imageOCR = FrameOCR()
    private let driverLocation = DriverLocation()
    private let trafficService = TrafficETAService()
    private var trafficTask: Task<Void, Never>?
    private let imageQueue = DispatchQueue(label: "fr.edendrive.iq.capture.ocr", qos: .userInitiated)
    private var stream: SCStream?
    private var settings: SettingsStore?
    private var mostRecentSignature: String?
    private var mostRecentOfferAt = Date.distantPast
    // Deux lectures identiques avant de notifier : évite d'agir sur un prix mal reconnu.
    private var candidateSignature: String?
    private var candidateSeenAt = Date.distantPast
    private var candidateConsecutiveCount = 0
    private var pickerRegistered = false

    init(settings: SettingsStore) {
        self.settings = settings
        pickerEvents.onSelection = { [weak self] filter in
            Task { @MainActor in await self?.beginCapture(filter: filter) }
        }
        pickerEvents.onCancel = { [weak self] in
            Task { @MainActor in
                guard let self, !self.isCapturing else { return }
                self.driverLocation.stopSession()
                self.statusText = "Capture non autorisée · surveillance inactive"
            }
        }
        pickerEvents.onError = { [weak self] description in
            Task { @MainActor in
                self?.driverLocation.stopSession()
                self?.statusText = "Capture impossible : \(description)"
            }
        }
        streamEvents.onStop = { [weak self] description in
            Task { @MainActor in
                self?.isCapturing = false
                self?.driverLocation.stopSession()
                self?.trafficTask?.cancel()
                self?.statusText = "Capture interrompue : \(description)"
            }
        }
        imageOCR.onRecognizedText = { [weak self] lines in
            Task { @MainActor in self?.consume(lines: lines) }
        }
    }

    func askToStart() {
        NotificationService.shared.requestPermission()
        driverLocation.startSession()
        if !pickerRegistered {
            picker.add(pickerEvents)
            pickerRegistered = true
        }
        picker.isActive = true
        var configuration = SCContentSharingPickerConfiguration()
        configuration.showsMicrophoneControl = false
        configuration.showsCameraControl = false
        picker.defaultConfiguration = configuration
        statusText = "Autorise le partage de l'écran complet…"
        picker.present()   // Apple impose le consentement explicite.
    }

    private func beginCapture(filter: SCContentFilter) async {
        if let previous = stream {
            try? await previous.stopCapture()
            stream = nil
        }
        let config = SCStreamConfiguration()
        config.width = Int(UIScreen.main.nativeBounds.width)
        config.height = Int(UIScreen.main.nativeBounds.height)
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 6)
        config.queueDepth = 3
        do {
            let newStream = SCStream(filter: filter, configuration: config, delegate: streamEvents)
            try newStream.addStreamOutput(imageOCR, type: .screen, sampleHandlerQueue: imageQueue)
            try await newStream.startCapture()
            stream = newStream
            isCapturing = true
            statusText = "Capture active · ouvre Uber ou Bolt"
        } catch {
            statusText = "Erreur de capture : \(error.localizedDescription)"
            isCapturing = false
            driverLocation.stopSession()
        }
    }

    func stopCapture() async {
        trafficTask?.cancel()
        trafficTask = nil
        driverLocation.stopSession()
        if let active = stream { try? await active.stopCapture() }
        stream = nil
        isCapturing = false
        picker.isActive = false
        if pickerRegistered {
            picker.remove(pickerEvents)
            pickerRegistered = false
        }
        statusText = "Capture arrêtée"
    }

    private func consume(lines: [String]) {
        guard isCapturing, let offer = OfferParser.parse(lines: lines), let settings else { return }
        // Les offres sont brèves. Deux frames cohérentes consécutives suffisent ; sinon silence.
        let now = Date()
        if candidateSignature == offer.signature && now.timeIntervalSince(candidateSeenAt) < 3 {
            candidateConsecutiveCount += 1
        } else {
            candidateSignature = offer.signature
            candidateConsecutiveCount = 1
        }
        candidateSeenAt = now
        guard candidateConsecutiveCount >= 2 else {
            statusText = "Lecture de l'offre · vérification du montant…"
            return
        }
        // Un même écran est vu plusieurs fois; notifier une seule fois pour l'offre.
        if offer.signature == mostRecentSignature && Date().timeIntervalSince(mostRecentOfferAt) < 90 { return }
        mostRecentSignature = offer.signature
        mostRecentOfferAt = Date()
        trafficTask?.cancel()
        let signature = offer.signature
        let defaultResult = Profitability.evaluate(offer, costs: settings.parameters)
        latest = defaultResult
        detectedCount += 1
        // Ne jamais envoyer un « PRENDRE » sur une durée inventée.
        // En l'absence de données d'itinéraire, notifier À VÉRIFIER, pas un verdict définitif.
        guard offer.pickupAddress != nil, offer.destination != nil,
              let current = driverLocation.recentLocation else {
            statusText = "Offre à vérifier · adresse ou GPS indisponible"
            NotificationService.shared.send(defaultResult, id: signature)
            return
        }
        statusText = "Offre détectée · vérification du trafic Apple Plans…"
        trafficTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let estimate = await self.trafficService.calculate(for: offer, from: current)
            guard !Task.isCancelled, self.isCapturing, self.mostRecentSignature == signature else { return }
            guard let estimate else {
                self.statusText = "Offre à vérifier · trafic non confirmé"
                NotificationService.shared.send(defaultResult, id: signature)
                return
            }
            let updated = Profitability.evaluate(offer, costs: settings.parameters, traffic: estimate)
            self.latest = updated
            self.statusText = "Offre analysée · trafic Apple Plans intégré"
            // Une seule notification utile et définitive, après validation du trafic.
            NotificationService.shared.send(updated, id: signature)
        }
    }
}
