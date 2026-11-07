import Foundation
import ScreenCaptureKit
import Vision
import CoreMedia
import CoreVideo

/// Ne stocke ni la vidéo ni les images. OCR sur appareil environ toutes les 1,5 s.
final class FrameOCR: NSObject, SCStreamOutput {
    var onRecognizedText: (([String]) -> Void)?
    private var lastProcessed = Date.distantPast

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              Date().timeIntervalSince(lastProcessed) > 1.5,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastProcessed = Date()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["fr-FR", "en-US"]
        do {
            try VNImageRequestHandler(cvPixelBuffer: buffer, options: [:]).perform([request])
            let observations = (request.results ?? []).sorted {
                if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.025 {
                    return $0.boundingBox.midY > $1.boundingBox.midY
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            if !lines.isEmpty { onRecognizedText?(lines) }
        } catch {
            // Une image illisible ne provoque aucune fausse alerte.
        }
    }
}
