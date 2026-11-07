import Foundation

/// Hypothèses de frais : ne définissent PAS le verdict 1 €/minute.
/// Le seuil porte sur le montant chauffeur affiché par Uber/Bolt AVANT frais du véhicule.
struct CostParameters: Sendable {
    var consumptionKWh100KM: Double = 16
    var energyPriceEURKWh: Double = 0.23
    var fixedMonthlyEUR: Double = 730
    var monthlyKM: Double = 8_800
    var wearAndMaintenanceEURKM: Double = 0.08
    var targetGrossEURMinute: Double = 1.00
    var estimatedTripSpeedKMH: Double = 27
}

/// Apple Plans fournit une ETA avec trafic attendu sur deux portions distinctes.
struct TrafficETA: Sendable {
    let pickupMinutes: Double
    let rideMinutes: Double
    let pickupKM: Double
    let rideKM: Double

    var isPlausible: Bool {
        pickupMinutes.isFinite && rideMinutes.isFinite &&
        pickupMinutes > 0 && rideMinutes > 0 &&
        pickupMinutes < 240 && rideMinutes < 600 &&
        pickupKM >= 0 && rideKM > 0 && pickupKM + rideKM < 1000
    }
}

struct OfferAnalysis: Sendable {
    enum Verdict: String, Sendable {
        case accept = "PRENDRE"
        case review = "À VÉRIFIER"
        case reject = "REFUSER"
    }
    enum DurationSource: String, Sendable {
        case traffic = "Trafic Apple Plans"
        case platform = "Durées Uber/Bolt"
        case estimated = "Durée approximative, sans trafic"
    }

    let offer: TripOffer
    let verdict: Verdict
    let totalKM: Double
    let pickupMinutes: Double
    let rideMinutes: Double
    let totalMinutes: Double
    let durationSource: DurationSource
    let grossEURMinute: Double
    let targetFareEUR: Double
    let grossHourlyEUR: Double
    let farePerKM: Double
    let costsEUR: Double
    let contributionEUR: Double
    let contributionHourlyEUR: Double
    let score: Int

    var durationEstimated: Bool { durationSource == .estimated }
    var gapToTargetEUR: Double { offer.fareEUR - targetFareEUR }
}

enum Profitability {
    /// Le verdict ne prend JAMAIS seulement le temps client : approche + course obligatoires.
    /// Sans durée fiable, aucun verdict PRENDRE automatique n'est émis.
    static func evaluate(_ offer: TripOffer, costs: CostParameters, traffic: TrafficETA? = nil) -> OfferAnalysis {
        let withTraffic = traffic?.isPlausible == true
        let pickupKM = withTraffic ? traffic!.pickupKM : offer.pickupKM
        let rideKM = withTraffic ? traffic!.rideKM : offer.rideKM
        let totalKM = pickupKM + rideKM
        let pickupMinutes = withTraffic ? traffic!.pickupMinutes :
            (offer.pickupMinutes ?? (offer.pickupKM / 23 * 60))
        let rideMinutes = withTraffic ? traffic!.rideMinutes :
            (offer.rideMinutes ?? (offer.rideKM / max(10, costs.estimatedTripSpeedKMH) * 60))
        let source: OfferAnalysis.DurationSource = withTraffic ? .traffic :
            ((offer.pickupMinutes != nil && offer.rideMinutes != nil) ? .platform : .estimated)
        let totalMinutes = max(1, pickupMinutes + rideMinutes)
        let energyEURKM = (costs.consumptionKWh100KM / 100) * costs.energyPriceEURKWh
        let fixedEURKM = costs.fixedMonthlyEUR / max(1, costs.monthlyKM)
        let costsEUR = (energyEURKM + fixedEURKM + costs.wearAndMaintenanceEURKM) * totalKM
        let contributionEUR = offer.fareEUR - costsEUR
        let grossEURMinute = offer.fareEUR / totalMinutes
        let targetGross = max(0.10, costs.targetGrossEURMinute)
        let targetFare = targetGross * totalMinutes
        let verdict: OfferAnalysis.Verdict
        if source == .estimated {
            verdict = .review
        } else if grossEURMinute >= targetGross {
            verdict = .accept
        } else {
            verdict = .reject
        }
        let score = max(1, min(10, Int((grossEURMinute / targetGross * 8).rounded())))
        return OfferAnalysis(offer: offer, verdict: verdict, totalKM: totalKM,
                             pickupMinutes: pickupMinutes, rideMinutes: rideMinutes,
                             totalMinutes: totalMinutes, durationSource: source,
                             grossEURMinute: grossEURMinute, targetFareEUR: targetFare,
                             grossHourlyEUR: grossEURMinute * 60,
                             farePerKM: offer.fareEUR / max(0.01, totalKM),
                             costsEUR: costsEUR, contributionEUR: contributionEUR,
                             contributionHourlyEUR: contributionEUR / totalMinutes * 60,
                             score: score)
    }
}
