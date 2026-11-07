import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var targetGrossEURMinute: Double { didSet { defaults.set(targetGrossEURMinute, forKey: "targetGrossEURMinute") } }
    @Published var consumption: Double { didSet { defaults.set(consumption, forKey: "consumption") } }
    @Published var energyPrice: Double { didSet { defaults.set(energyPrice, forKey: "energyPrice") } }
    @Published var fixedMonthly: Double { didSet { defaults.set(fixedMonthly, forKey: "fixedMonthly") } }
    @Published var monthlyKM: Double { didSet { defaults.set(monthlyKM, forKey: "monthlyKM") } }
    @Published var wearEURKM: Double { didSet { defaults.set(wearEURKM, forKey: "wearEURKM") } }
    @Published var travelSpeed: Double { didSet { defaults.set(travelSpeed, forKey: "travelSpeed") } }

    init() {
        func read(_ key: String, default value: Double) -> Double {
            defaults.object(forKey: key) == nil ? value : defaults.double(forKey: key)
        }
        targetGrossEURMinute = read("targetGrossEURMinute", default: 1)
        consumption = read("consumption", default: 16)
        energyPrice = read("energyPrice", default: 0.23)
        fixedMonthly = read("fixedMonthly", default: 730)
        monthlyKM = read("monthlyKM", default: 8_800)
        wearEURKM = read("wearEURKM", default: 0.08)
        travelSpeed = read("travelSpeed", default: 27)
    }

    var parameters: CostParameters {
        CostParameters(consumptionKWh100KM: max(1, consumption),
                       energyPriceEURKWh: max(0, energyPrice),
                       fixedMonthlyEUR: max(0, fixedMonthly),
                       monthlyKM: max(1, monthlyKM),
                       wearAndMaintenanceEURKM: max(0, wearEURKM),
                       targetGrossEURMinute: max(0.1, targetGrossEURMinute),
                       estimatedTripSpeedKMH: max(10, travelSpeed))
    }
}
