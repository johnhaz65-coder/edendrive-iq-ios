import Foundation
import CoreLocation
import MapKit

/// Apple Plans ne transmet pas de carte de bouchons ; calculateETA intègre le trafic attendu.
/// Les adresses OCR et la position sont adressées aux services Apple Maps pour le calcul.
@MainActor
final class TrafficETAService {
    func calculate(for offer: TripOffer, from current: CLLocation) async -> TrafficETA? {
        guard let pickupText = offer.pickupAddress, let destinationText = offer.destination,
              !Task.isCancelled else { return nil }
        do {
            // Le résultat de recherche n'est qu'une hypothèse. Rejeter les trajets incohérents
            // avec les kilomètres affichés par Uber/Bolt évite les mauvaises destinations.
            let pickup = try await findAddress(pickupText, near: current.coordinate)
            let destination = try await findAddress(destinationText, near: pickup.placemark.coordinate)
            guard !Task.isCancelled else { return nil }

            let now = Date()
            let approach = try await eta(from: MKMapItem(placemark: MKPlacemark(coordinate: current.coordinate)),
                                         to: pickup, leaving: now)
            guard !Task.isCancelled else { return nil }
            let ride = try await eta(from: pickup, to: destination,
                                     leaving: now.addingTimeInterval(approach.expectedTravelTime))
            let result = TrafficETA(pickupMinutes: approach.expectedTravelTime / 60,
                                    rideMinutes: ride.expectedTravelTime / 60,
                                    pickupKM: approach.distance / 1000,
                                    rideKM: ride.distance / 1000)
            guard result.isPlausible,
                  Self.distanceMatches(result.pickupKM, shownKM: offer.pickupKM),
                  Self.distanceMatches(result.rideKM, shownKM: offer.rideKM) else { return nil }
            return result
        } catch {
            // Hors ligne, adresses ambiguës, service indisponible ou limitation MapKit.
            return nil
        }
    }

    private func findAddress(_ text: String, near coordinate: CLLocationCoordinate2D) async throws -> MKMapItem {
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 120_000, longitudinalMeters: 120_000)
        let request = MKLocalSearch.Request(naturalLanguageQuery: text, region: region)
        request.resultTypes = [.address, .pointOfInterest]
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { throw URLError(.cannotFindHost) }
        return item
    }

    private func eta(from origin: MKMapItem, to destination: MKMapItem, leaving: Date) async throws -> MKDirections.ETAResponse {
        let request = MKDirections.Request()
        request.source = origin
        request.destination = destination
        request.transportType = .automobile
        request.departureDate = leaving
        // Ne pas multiplier les routes : Apple limite les requêtes trop fréquentes.
        return try await MKDirections(request: request).calculateETA()
    }

    /// Contrôle de cohérence OCR / cartographie. Les deux peuvent différer, mais pas fortement.
    static func distanceMatches(_ mappedKM: Double, shownKM: Double) -> Bool {
        guard mappedKM.isFinite, shownKM.isFinite, mappedKM >= 0, shownKM >= 0 else { return false }
        return abs(mappedKM - shownKM) <= max(1.5, shownKM * 0.45)
    }
}
