import Foundation

@main
struct SmokeMain {
    static func main() throws {
        let path = CommandLine.arguments.dropFirst().first ?? "Fixtures/uber_offer.txt"
        let raw = try String(contentsOfFile: path, encoding: .utf8)
        guard let trip = OfferParser.parse(lines: raw.components(separatedBy: .newlines)) else {
            fatalError("Échec OCR simulé : offre non lue")
        }
        precondition(trip.platform == .uber)
        precondition(trip.fareEUR == 9)
        precondition(trip.pickupKM == 1.9)
        precondition(trip.rideKM == 6.4)
        precondition(trip.pickupAddress?.contains("Louis Bonnefon") == true)
        precondition(trip.destination?.contains("Corse") == true)
        let analysis = Profitability.evaluate(trip, costs: CostParameters())
        precondition(analysis.totalKM > 8.29 && analysis.totalKM < 8.31)
        precondition(analysis.costsEUR > 0)
        precondition(analysis.totalMinutes >= 5)
        precondition(analysis.durationSource == .estimated)
        // Simulation du retour ETA Apple Plans : trafic plus lent => moins bon €/heure.
        let withTraffic = Profitability.evaluate(trip, costs: CostParameters(),
                           traffic: TrafficETA(pickupMinutes: 8, rideMinutes: 24,
                                               pickupKM: 2.0, rideKM: 6.7))
        precondition(withTraffic.durationSource == .traffic)
        precondition(withTraffic.totalMinutes == 32)
        precondition(withTraffic.contributionHourlyEUR < analysis.contributionHourlyEUR)
        let invalidTraffic = Profitability.evaluate(trip, costs: CostParameters(),
                             traffic: TrafficETA(pickupMinutes: -1, rideMinutes: 0,
                                                 pickupKM: 0, rideKM: 0))
        precondition(invalidTraffic.durationSource == .estimated)
        print("OK : \(trip.platform.rawValue) \(trip.fareEUR) €, \(analysis.totalKM) km, score \(analysis.score)/10, marge estimée \(String(format: "%.2f", analysis.contributionEUR)) €")
    }
}
