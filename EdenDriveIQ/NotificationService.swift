import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func send(_ result: OfferAnalysis, id: String, replacing: Bool = false) {
        let n = UNMutableNotificationContent()
        n.title = "\(result.verdict.rawValue) · \(String(format: "%.2f", result.grossEURMinute)) €/min · \(String(format: "%.2f", result.offer.fareEUR)) €"
        let source: String = result.durationSource == .traffic ? "trafic Apple Plans" :
            (result.durationEstimated ? "durée estimée sans trafic" : "durées plateforme")
        let gap = result.gapToTargetEUR >= 0 ? "+\(String(format: "%.2f", result.gapToTargetEUR)) €" : "Manque \(String(format: "%.2f", -result.gapToTargetEUR)) €"
        n.body = "\(Int(result.pickupMinutes.rounded())) min approche + \(Int(result.rideMinutes.rounded())) min course = \(Int(result.totalMinutes.rounded())) min · \(gap) · \(source)"
        n.threadIdentifier = "edendrive-offers"
        // Aucune alerte sonore si la durée est provisoire.
        if !result.durationEstimated { n.sound = .default }
        let identifier = "offer-\(id)"
        if replacing {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: n, trigger: nil),
                                               withCompletionHandler: nil)
    }
}
