import SwiftUI
import OffsideGolfCore

struct SettingsView: View {
    @Environment(PlayerStore.self) private var player
    var body: some View {
        Form {
            Section("Sound & touch") {
                volume("Music", \.musicVolume)
                volume("Nature", \.ambientVolume)
                volume("Golf sounds", \.effectsVolume)
                volume("Interface", \.interfaceVolume)
                toggle("Haptics", \.hapticsEnabled)
            }
            Section("Play your way") {
                toggle("Untimed power controls", \.preciseControls)
                toggle("Left-handed controls", \.leftHanded)
                toggle("Green slope guides", \.slopeGuide)
            }
            Section("Readability & motion") {
                toggle("Reduce motion", \.reducedMotion)
                toggle("High-contrast aiming", \.highContrast)
                Text("Menus follow your device’s text size. Wind, sand and water also use symbols and patterns.")
                    .font(.footnote)
            }
            Section {
                Button("Replay the short tutorial") {
                    showTutorial = true
                }
                .sheet(isPresented: $showTutorial) { TutorialHelpView() }
            }
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings.screen")
    }
    @State private var showTutorial = false
    private func toggle(_ label: String,_ key: WritableKeyPath<GameSettings,Bool>) -> some View {
        Toggle(label,isOn: Binding(get: { player.settings[keyPath:key] },set: { value in
            var settings = player.settings; settings[keyPath:key] = value; player.updateSettings(settings)
        }))
    }
    private func volume(_ label: String,_ key: WritableKeyPath<GameSettings,Double>) -> some View {
        VStack(alignment: .leading) {
            Text(label)
            Slider(value: Binding(get: { player.settings[keyPath:key] },set: { value in
                var settings = player.settings;settings[keyPath:key] = value;player.updateSettings(settings)
            }),in: 0...1,step: 0.05).accessibilityLabel("\(label) volume")
        }
    }
}

struct TutorialHelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Label("Tap the course to aim, or use Aim at flag and the direction buttons.",systemImage: "scope")
                Label("Pull down on the swing pad. Release to swing; slide sideways to cancel.",systemImage: "hand.draw")
                Label("For an untimed alternative, choose precise controls, set power, then tap Swing.",systemImage: "slider.horizontal.3")
                Label("Choose a club for the distance. The dotted arc and landing circle are a guide.",systemImage: "flag")
                Label("The arrow shows where wind is blowing. Airborne shots drift with it.",systemImage: "wind")
                Label("On the green, select a short putting range for finer control.",systemImage: "circle.dotted")
                Label("Water and out of bounds add one penalty stroke and return the ball to a safe lie.",systemImage: "water.waves")
            }.navigationTitle("A few small swings")
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}
