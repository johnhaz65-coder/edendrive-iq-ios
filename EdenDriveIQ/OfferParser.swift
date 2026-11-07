import Foundation

/// Extraction conservatrice : ne crée pas d'offre si le tarif ou les distances manquent.
struct TripOffer: Equatable, Sendable {
    enum Platform: String, Sendable {
        case uber = "Uber"
        case bolt = "Bolt"
    }

    let platform: Platform
    let fareEUR: Double
    let pickupKM: Double
    let pickupMinutes: Double?
    let rideKM: Double
    let rideMinutes: Double?
    let pickupAddress: String?
    let destination: String?

    var totalKM: Double { pickupKM + rideKM }
    var signature: String {
        "\(platform.rawValue)|\(Int((fareEUR * 100).rounded()))|\(Int((pickupKM * 10).rounded()))|\(Int((rideKM * 10).rounded()))|\(pickupAddress ?? "")|\(destination ?? "")"
    }
}

enum OfferParser {
    static func parse(lines rawLines: [String]) -> TripOffer? {
        let lines = rawLines.map {
            $0.replacingOccurrences(of: "\u{00a0}", with: " ")
                .replacingOccurrences(of: "\u{202f}", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        // Chercher la carte Uber/Bolt plutôt qu'une notification d'analyse déjà affichée.
        guard let headerIndex = lines.firstIndex(where: { line in
            let low = line.lowercased()
            return low.contains("uberx") || low == "uber" || low.contains("bolt")
        }) else { return nil }
        let header = lines[headerIndex].lowercased()
        let platform: TripOffer.Platform = header.contains("bolt") ? .bolt : .uber
        let offerLines = Array(lines[headerIndex...])
        let joined = offerLines.joined(separator: " | ")
        guard joined.localizedCaseInsensitiveContains("course") ||
              joined.localizedCaseInsensitiveContains("mise en relation") ||
              joined.localizedCaseInsensitiveContains("trajet") else { return nil }

        let currency = #"(?i)(?:^|\s)([0-9]{1,3}(?:[.,][0-9]{1,2})?)\s*€"#
        // Le prix de la proposition apparaît normalement juste après l'entête UberX/Bolt.
        let priceSearchArea = Array(offerLines.prefix(7))
        guard let price = priceSearchArea.compactMap({ matchNumber(in: $0, pattern: currency, group: 1) }).first,
              price > 0, price < 1500 else { return nil }

        let pickupPattern = #"(?i)([0-9]{1,2})\s*min(?:ute)?s?\s*[·•\-–]\s*([0-9]+(?:[.,][0-9]+)?)\s*km"#
        let tripPattern = #"(?i)(?:course|trajet)\s*(?:de|:)?\s*([0-9]+(?:[.,][0-9]+)?)\s*km"#
        guard let pickupLine = offerLines.first(where: { matchNumber(in: $0, pattern: pickupPattern, group: 2) != nil }),
              let pickupKM = matchNumber(in: pickupLine, pattern: pickupPattern, group: 2),
              let rideLineIndex = offerLines.firstIndex(where: { matchNumber(in: $0, pattern: tripPattern, group: 1) != nil }),
              let rideKM = matchNumber(in: offerLines[rideLineIndex], pattern: tripPattern, group: 1),
              pickupKM >= 0, rideKM > 0, pickupKM + rideKM < 1000 else { return nil }
        let pickupMinutes = matchNumber(in: pickupLine, pattern: pickupPattern, group: 1)
        let durationPattern = #"(?i)(?:trajet|course)\s*[:\-]?\s*([0-9]{1,3})\s*min"#
        let rideMinutes = offerLines.compactMap({ matchNumber(in: $0, pattern: durationPattern, group: 1) }).first
        let pickupLineIndex = offerLines.firstIndex(of: pickupLine)!
        let pickupAddress: String? = {
            let candidateIndex = pickupLineIndex + 1
            guard candidateIndex < rideLineIndex else { return nil }
            return cleanAddress(offerLines[candidateIndex])
        }()
        let destination: String? = {
            let candidateIndex = rideLineIndex + 1
            guard offerLines.indices.contains(candidateIndex) else { return nil }
            return cleanAddress(offerLines[candidateIndex])
        }()

        return TripOffer(platform: platform, fareEUR: price, pickupKM: pickupKM,
                         pickupMinutes: pickupMinutes, rideKM: rideKM,
                         rideMinutes: rideMinutes, pickupAddress: pickupAddress, destination: destination)
    }

    /// Ne pas envoyer une ligne descriptive à Apple Plans comme s'il s'agissait d'une adresse.
    private static func cleanAddress(_ text: String) -> String? {
        let lower = text.lowercased()
        guard text.count >= 5, text.count <= 150,
              !lower.contains("mise en relation"), !lower.contains("montant net"),
              !lower.contains("course de"), !lower.contains("trajet de"),
              !lower.contains("min"), !lower.contains("€"), !lower.contains(" km") else { return nil }
        // Une rue numérotée ou un lieu identifié (gare, hôtel, aéroport…) peut être recherché.
        let hasAddressHint = text.range(of: #"\d{1,4}\s+\p{L}"#, options: .regularExpression) != nil
        let isKnownPlace = ["gare", "aéroport", "airport", "hôtel", "hotel", "station", "avenue", "boulevard", "rue", "quai", "place"].contains { lower.contains($0) }
        return (hasAddressHint || isKnownPlace) ? text : nil
    }

    private static func matchNumber(in text: String, pattern: String, group: Int) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > group,
              let range = Range(match.range(at: group), in: text) else { return nil }
        return Double(text[range].replacingOccurrences(of: ",", with: "."))
    }
}
