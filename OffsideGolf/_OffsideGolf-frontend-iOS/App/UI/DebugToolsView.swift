#if DEBUG
import SwiftUI
import OffsideGolfCore

struct DebugToolsView: View {
    let session: GameSession
    let selectHole: (Int) -> Void
    @State private var wind = 0.0
    @State private var direction = 0.0
    @State private var selectedHole = 1
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Developer tools · Records disabled") {
                    Text("Physics tools and detailed guides make this round ineligible for records.").font(.footnote)
                    Toggle("FPS and node count",isOn: Binding(get: { session.scene.view?.showsFPS ?? false },set: { value in
                        session.scene.view?.showsFPS = value;session.scene.view?.showsNodeCount = value
                    }))
                    Toggle("Collision and terrain labels",isOn: Binding(get: { session.scene.debugGeometry },set: { session.setDebugGeometry($0) }))
                    Toggle("Full trajectory",isOn: Binding(get: { session.scene.debugTrajectory },set: { session.setDebugTrajectory($0) }))
                    Picker("Simulation speed",selection: Binding(get: { session.debugSpeed },set: { session.setDebugSpeed($0) })) {
                        Text("¼ speed").tag(0.25);Text("Normal").tag(1.0);Text("4× speed").tag(4.0)
                    }
                }
                Section("Wind override") {
                    Slider(value: $wind,in: 0...12,step: 0.5) { Text("Wind speed") }
                    Text("\(wind,specifier: "%.1f") mph")
                    Slider(value: $direction,in: 0...360,step: 15) { Text("Wind direction") }
                    Button("Apply wind") { session.debugWind(speed: wind,direction: direction) }
                }
                Section("Ball and hole") {
                    Button("Move to tee") { session.debugTeleport(session.hole.tee) }
                    Button("Move near the cup") { session.debugTeleport(session.hole.pin + Vector2(x: 0,y: -2)) }
                    Button("Set power to 50%") { session.resume();session.setPower(0.5);session.markAssisted();dismiss() }
                    Button("Complete current hole") { session.debugComplete();dismiss() }.accessibilityIdentifier("debug.complete")
                    Picker("Hole",selection: $selectedHole) { ForEach(1...9,id: \.self) { Text("Hole \($0)").tag($0) } }
                    Button("Open selected hole") { selectHole(selectedHole);dismiss() }
                }
                if let url = Bundle.main.url(forResource: session.hole.id,withExtension: "json") {
                    Section("Content authoring") { ShareLink("Export authored hole JSON",item: url) }
                }
            }.navigationTitle("Developer tools").toolbar { Button("Done") { dismiss() } }
                .onAppear { wind = session.hole.wind.speedMPH;direction = session.hole.wind.towardDegrees }
        }
    }
}
#endif
