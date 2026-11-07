import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Ta règle numéro 1") {
                HStack {
                    Text("CA minimum / minute")
                    Spacer()
                    TextField("1", value: $settings.targetGrossEURMinute,
                              format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("€")
                }
                Text("1 €/minute = 60 €/heure. Toujours APPROCHE + COURSE. Le montant est celui affiché par Uber ou Bolt, avant les frais du véhicule.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Tesla / recharge") {
                parameter("Consommation (kWh/100 km)", value: $settings.consumption)
                parameter("Prix réel recharge (€/kWh)", value: $settings.energyPrice)
            }
            Section("Charges de ton activité") {
                parameter("Charges fixes mensuelles (€)", value: $settings.fixedMonthly)
                parameter("Kilométrage mensuel (km)", value: $settings.monthlyKM)
                parameter("Usure et entretien (€/km)", value: $settings.wearEURKM)
            }
            Section("Mode dégradé") {
                parameter("Vitesse si trafic absent (km/h)", value: $settings.travelSpeed)
                Text("Sans durée de trajet vérifiée, le verdict reste À VÉRIFIER, jamais PRENDRE automatiquement.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Text("Les frais sont informatifs et non déduits du seuil de 1 €/minute. Ce n'est pas une estimation du bénéfice après cotisations et impôts.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Mon objectif")
    }

    private func parameter(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer(minLength: 8)
            TextField("0", value: value, format: .number.precision(.fractionLength(0...3)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 82)
        }
    }
}
