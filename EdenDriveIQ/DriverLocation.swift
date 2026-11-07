import Foundation
import CoreLocation

/// Localisation en session VTC uniquement ; jamais conservée ni envoyée par nous.
/// iOS peut afficher l'indicateur de localisation en arrière-plan.
@MainActor
final class DriverLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var isTracking = false
    private(set) var latestLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 25
        manager.pausesLocationUpdatesAutomatically = false
    }

    func startSession() {
        isTracking = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            break
        }
    }

    private func beginUpdates() {
        guard isTracking else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stopSession() {
        isTracking = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        latestLocation = nil
    }

    var recentLocation: CLLocation? {
        guard let last = latestLocation,
              abs(last.timestamp.timeIntervalSinceNow) < 45,
              last.horizontalAccuracy >= 0, last.horizontalAccuracy < 150 else { return nil }
        return last
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            beginUpdates()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last, last.horizontalAccuracy >= 0 { latestLocation = last }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Pas de fausse durée trafic : le système reviendra à l'estimation locale.
    }
}
