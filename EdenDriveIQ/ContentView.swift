import SwiftUI

struct ContentView: View {
    @StateObject private var settings: SettingsStore
    @StateObject private var capture: CaptureManager

    init() {
        let sharedSettings = SettingsStore()
        _settings = StateObject(wrappedValue: sharedSettings)
        _capture = StateObject(wrappedValue: CaptureManager(settings: sharedSettings))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heading
                    status
                    objectiveBanner
                    buttons
                    if let result = capture.latest {
                        resultCard(result)
                    } else {
                        ContentUnavailableView("Aucune course analysée", systemImage: "car.side",
                                               description: Text("Autorise la capture de l’écran complet, puis ouvre Uber ou Bolt. Le verdict repose sur approche + course."))
                    }
                    Text("Confidentialité : reconnaissance du texte sur l'iPhone. Aucune vidéo ni capture conservée ou envoyée. Pendant une session, iOS capture toutefois l'intégralité de l'écran que tu as autorisé.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("La lecture doit être confirmée sur deux images successives avant d'analyser le prix. Le verdict final n'arrive qu'après validation des durées ou reste À VÉRIFIER. Capture, Bolt et alertes à tester sur un vrai iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("EdenDrive IQ")
            .toolbar {
                NavigationLink(destination: SettingsView(settings: settings)) {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Réglages")
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ton copilote VTC").font(.largeTitle.bold())
            Text("Une activation, puis analyse des offres visibles sur Uber ou Bolt.")
                .foregroundStyle(.secondary)
        }
    }

    private var objectiveBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer").font(.title2.bold()).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 3) {
                Text("OBJECTIF : 1 € / MIN").font(.headline).foregroundStyle(.white)
                Text("Approche + course · trafic Apple Plans").font(.caption).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
    }

    private var status: some View {
        HStack(spacing: 10) {
            Image(systemName: capture.isCapturing ? "record.circle.fill" : "circle.dotted")
                .foregroundStyle(capture.isCapturing ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(capture.statusText).font(.subheadline.bold())
                Text("\(capture.detectedCount) offre(s) détectée(s)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                capture.askToStart()
            } label: {
                Label(capture.isCapturing ? "Modifier la capture" : "Activer la capture automatique", systemImage: "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if capture.isCapturing {
                Button(role: .destructive) {
                    Task { await capture.stopCapture() }
                } label: {
                    Label("Arrêter la surveillance", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func resultCard(_ result: OfferAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(result.offer.platform.rawValue).font(.subheadline).foregroundStyle(.secondary)
                    Text(euro(result.offer.fareEUR)).font(.largeTitle.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(result.verdict.rawValue).font(.headline.bold())
                        .foregroundStyle(verdictColor(result.verdict))
                    Text("Objectif : 1 €/min").font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.2f €/min", result.grossEURMinute))
                        .font(.system(size: 33, weight: .heavy, design: .rounded))
                        .foregroundStyle(verdictColor(result.verdict))
                    Spacer()
                    Text("Minimum : " + euro(result.targetFareEUR))
                        .font(.callout.bold())
                }
                ProgressView(value: min(1.0, max(0.0, result.grossEURMinute / max(0.1, settings.targetGrossEURMinute))))
                    .tint(verdictColor(result.verdict))
                Text(result.gapToTargetEUR >= 0
                     ? "Au-dessus de l'objectif : +" + euro(result.gapToTargetEUR)
                     : "Il manque " + euro(-result.gapToTargetEUR) + " pour atteindre ton objectif")
                    .font(.subheadline.bold())
            }
            Divider()
            HStack {
                metric("Distance totale", String(format: "%.1f km", result.totalKM))
                Spacer()
                metric("Durée totale", "\(Int(result.totalMinutes.rounded())) min")
                Spacer()
                metric("CA / km", euro(result.farePerKM))
            }
            Text("Approche : \(Int(result.pickupMinutes.rounded())) min · Course : \(Int(result.rideMinutes.rounded())) min")
                .font(.footnote).foregroundStyle(.secondary)
            Label(result.durationSource.rawValue, systemImage: result.durationSource == .traffic ? "car.side.rear.open" : "exclamationmark.triangle")
                .font(.caption).foregroundStyle(result.durationSource == .traffic ? .green : .orange)
            Divider()
            HStack {
                metric("CA / heure", "\(Int(result.grossHourlyEUR.rounded())) €/h")
                Spacer()
                metric("Coûts répartis", euro(result.costsEUR))
                Spacer()
                metric("Après frais / h", "\(Int(result.contributionHourlyEUR.rounded())) €/h")
            }
            Text("Marge estimée de cette course : \(euro(result.contributionEUR))")
                .font(.headline)
            if let destination = result.offer.destination {
                Label(destination, systemImage: "mappin.and.ellipse")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if result.durationSource != .traffic {
                Label("Trafic non confirmé : les chiffres sont indicatifs, pas un ETA en direct.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold())
        }
    }
    private func euro(_ value: Double) -> String { String(format: "%.2f €", value) }
    private func verdictColor(_ verdict: OfferAnalysis.Verdict) -> Color {
        switch verdict { case .accept: .green; case .review: .orange; case .reject: .red }
    }
}
