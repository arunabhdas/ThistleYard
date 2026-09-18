import SwiftUI
import OffsideGolfCore

struct SwingControls: View {
    let session: GameSession
    @State private var precision = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(spacing: 8) {
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading,spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            headerLayout {
                Menu {
                    ForEach(GolfClubType.allCases, id: \.self) { club in
                        Button("\(club.displayName) · \(Int(club.nominalCarryYards)) yd carry") {
                            session.send(.chooseClub(club))
                        }.accessibilityIdentifier("club.\(club.rawValue)")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(session.hud.club.displayName).font(.headline).accessibilityIdentifier("game.club")
                        Image(systemName: "chevron.down").font(.caption)
                    }
                }
                .disabled(!session.hud.canAim)
                .accessibilityIdentifier("club.selector")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("Power \(session.hud.power)%")
                    .font(.subheadline.monospacedDigit())
                    .accessibilityIdentifier("game.power")
            }
            if session.hud.club == .putter {
                Picker("Putting range", selection: Binding(get: { session.hud.puttRange }, set: { session.send(.setPuttRange($0)) })) {
                    ForEach(PuttRange.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.pickerStyle(.segmented).disabled(!session.hud.canAim).accessibilityIdentifier("putt.range")
            } else {
                Text("\(Int(session.hud.club.nominalCarryYards)) yd nominal carry · \(session.hud.lie.rawValue)")
                    .font(.caption).foregroundStyle(GolfTheme.secondary)
            }
            // Measure every advisory at the current width/text size, even when clear.
            // Prediction updates must never relocate a control beneath an active finger.
            ZStack(alignment: .leading) {
                ForEach(ShotPreviewWarning.allCases, id: \.self) { warning in
                    Label(warning.rawValue, systemImage: "exclamationmark.triangle")
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(session.previewWarning == warning ? 1 : 0)
                        .accessibilityHidden(session.previewWarning != warning)
                }
            }
            .font(.caption)
            .foregroundStyle(GolfTheme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            .transaction { $0.animation = nil }
            HStack(spacing: 8) {
                Button { session.rotateAim(degrees: 1) } label: {
                    Image(systemName: "arrow.counterclockwise").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Aim one degree left")
                Button("Aim at flag", action: session.aimAtFlag)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("aim.flag")
                Button { session.rotateAim(degrees: -1) } label: {
                    Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Aim one degree right")
            }
            .disabled(!session.hud.canAim)
            if precision {
                VStack(spacing: 6) {
                    Slider(value: Binding(get: { Double(session.hud.power) / 100 },
                                          set: { session.setPower($0) }), in: 0...1, step: 0.01)
                        .accessibilityLabel("Shot power")
                        .accessibilityValue("\(session.hud.power) percent")
                        .accessibilityIdentifier("swing.power")
                    HStack {
                        Button { session.setPower(Double(max(0, session.hud.power - 1)) / 100) } label: {
                            Image(systemName: "minus").frame(minWidth: 44, minHeight: 44)
                        }.accessibilityLabel("Decrease power").accessibilityIdentifier("power.decrease")
                        Spacer()
                        Button { session.setPower(Double(min(100, session.hud.power + 1)) / 100) } label: {
                            Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                        }.accessibilityLabel("Increase power").accessibilityIdentifier("power.increase")
                    }
                    Button("Swing") { session.send(.release) }
                        .buttonStyle(GolfPrimaryButtonStyle())
                        .disabled(session.hud.power == 0)
                        .accessibilityIdentifier("swing.commit")
                }.disabled(!session.hud.canAim)
            } else {
                SwingPad(session: session)
            }
            Button(precision ? "Use pull & release" : "Use precise power controls") {
                session.send(.cancelCharge)
                precision.toggle()
            }
            .font(.footnote).frame(minHeight: 44)
            .disabled(!session.hud.canAim)
            .accessibilityIdentifier("controls.precise")
        }
        .onAppear { precision = session.settings.preciseControls }
    }
}

private struct SwingPad: View {
    let session: GameSession
    @State private var tracking = false
    @State private var cancelled = false
    @State private var generation = 0
    @GestureState private var touching = false
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "arrow.down").font(.title2)
            Text(session.hud.canAim ? "Pull down, release to swing" : session.hud.phaseLabel)
                .font(.subheadline.weight(.semibold))
            Text("Slide sideways to cancel").font(.caption)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(GolfTheme.mist, in: RoundedRectangle(cornerRadius: 18))
        .contentShape(Rectangle())
        .highPriorityGesture(DragGesture(minimumDistance: 0)
            .updating($touching) { _, active, _ in active = true }
            .onChanged { value in
                if !tracking {
                    guard session.hud.canAim else { return }
                    tracking = true; cancelled = false
                    generation = session.inputGeneration
                    session.beginPull()
                }
                guard tracking, !cancelled else { return }
                guard generation == session.inputGeneration else {
                    cancelled = true
                    return
                }
                if abs(value.translation.width) > 80 {
                    cancelled = true; session.send(.cancelCharge)
                } else {
                    session.setPower(max(0, min(1, value.translation.height / 110)))
                }
            }
            .onEnded { value in
                if tracking && !cancelled && generation == session.inputGeneration && value.translation.height >= 8 {
                    session.send(.release)
                } else { session.send(.cancelCharge) }
                session.endPull()
                tracking = false; cancelled = false
            })
        .onChange(of: touching) { _, active in
            if !active && tracking {
                session.send(.cancelCharge)
                tracking = false; cancelled = true
            }
        }
        .onChange(of: session.hud.phase) { _, phase in
            if phase != .charging && phase != .aiming { tracking = false; cancelled = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Swing pad")
        .accessibilityHint("Use precise power controls for adjustable power and a swing button.")
        .accessibilityIdentifier("swing.pad")
    }
}
