import Foundation

@main
struct DecisionCases {
    static func main() {
        let costs = CostParameters()
        func example(_ price: Double, _ approach: Double, _ ride: Double, expected: OfferAnalysis.Verdict) {
            let offer = TripOffer(platform: .uber, fareEUR: price, pickupKM: 1.2,
                                  pickupMinutes: approach, rideKM: 5.0, rideMinutes: ride,
                                  pickupAddress: "24 Boulevard Baptiste Cayol Marseille",
                                  destination: "108 Boulevard de Pont de Vivaux Marseille")
            let result = Profitability.evaluate(offer, costs: costs,
                traffic: TrafficETA(pickupMinutes: approach, rideMinutes: ride, pickupKM: 1.2, rideKM: 5.0))
            precondition(result.verdict == expected, "Bad verdict for price \(price)")
            precondition(abs(result.totalMinutes - approach - ride) < 0.00001)
            print(String(format: "OK %.2f € / %.0f min = %.2f €/min : %@", price, result.totalMinutes, result.grossEURMinute, result.verdict.rawValue))
        }
        example(24.80, 6, 13, expected: .accept)
        example(10.76, 4, 15, expected: .reject)
        example(19.00, 4, 15, expected: .accept)
        example(9.00, 9, 6, expected: .reject)
        example(11.01, 4, 16, expected: .reject)
        example(12.83, 6, 18, expected: .reject)
        let missing = TripOffer(platform: .bolt, fareEUR: 20, pickupKM: 2, pickupMinutes: 6, rideKM: 8,
                                rideMinutes: nil, pickupAddress: nil, destination: nil)
        let fallback = Profitability.evaluate(missing, costs: costs)
        precondition(fallback.verdict == .review)
        print("OK : si la durée/trafic n'est pas confirmé, À VÉRIFIER")
    }
}
