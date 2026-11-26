import PTPCore
import SwiftUI

/// The owner's settings, kept in the iPhone's UserDefaults. The alert distances also go to the watch, which uses
/// them from its next arm (ADR-0016).
struct SettingsView: View {
    static let alertDistanceKey = "alertDistance"
    static let eventAlertDistanceKey = "eventAlertDistance"
    static let promptNewAreasKey = "promptNewAreas"
    static let promptRiskyPlacesKey = "promptRiskyPlaces"
    private static let config = DetectionConfig.standard

    let exchange: TokenExchange
    let visitLearner: VisitLearner
    let placeWatcher: PlaceWatcher
    @AppStorage(alertDistanceKey) private var alertDistance = Double(config.alertDistance)
    @AppStorage(eventAlertDistanceKey) private var eventAlertDistance = Double(config.eventAlertDistance)
    @AppStorage(promptNewAreasKey) private var promptNewAreas = true
    @AppStorage(promptRiskyPlacesKey) private var promptRiskyPlaces = true

    /// A prompt is on unless the owner turned it off.
    static func isOn(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    static func publishAlertDistances(to exchange: TokenExchange) {
        let defaults = UserDefaults.standard
        exchange.publishAlertDistances(
            alert: defaults.object(forKey: alertDistanceKey) as? Double ?? Double(config.alertDistance),
            event: defaults.object(forKey: eventAlertDistanceKey) as? Double ?? Double(config.eventAlertDistance))
    }

    var body: some View {
        Form {
            Section {
                distanceStepper("Normal", value: $alertDistance, range: Self.config.alertDistanceRange)
                distanceStepper("Event mode", value: $eventAlertDistance, range: Self.config.eventAlertDistanceRange)
            } header: {
                Text("Alert distance")
            } footer: {
                Text("The watch warns when your iPhone is farther than this. A change applies the next time it arms.")
            }

            Section("Ask to arm") {
                Toggle("In new areas", isOn: $promptNewAreas)
                Toggle("At risky places", isOn: $promptRiskyPlaces)
            }

            Section {
                LabeledContent("Places learned", value: "\(visitLearner.areas) areas")
                if !visitLearner.isLearning {
                    Button(
                        visitLearner.needsSettings ? "Allow location “Always” in Settings" : "Learn places",
                        action: visitLearner.start)
                }
                Button("Delete learned places", role: .destructive, action: visitLearner.deleteAll)
                LabeledContent("Risky · Safe", value: "\(placeWatcher.riskyCount) · \(placeWatcher.safeCount)")
                Group {
                    Button("Mark here as risky") { placeWatcher.mark(.risky) }
                    Button("Mark here as safe") { placeWatcher.mark(.safe) }
                }
                .disabled(placeWatcher.isLocating || !visitLearner.isLearning)
                Button("Remove chosen places", role: .destructive, action: placeWatcher.deleteAll)
                    .disabled(placeWatcher.isLocating)
            } header: {
                Text("Places")
            } footer: {
                if let problem = placeWatcher.markProblem { Text(problem) }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: [alertDistance, eventAlertDistance]) { Self.publishAlertDistances(to: exchange) }
    }

    private func distanceStepper(_ label: String, value: Binding<Double>, range: ClosedRange<Float>) -> some View {
        Stepper(
            value: value, in: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(Self.config.ownerDistanceStep)
        ) {
            LabeledContent(label, value: "\(value.wrappedValue.formatted()) m")
        }
    }
}
