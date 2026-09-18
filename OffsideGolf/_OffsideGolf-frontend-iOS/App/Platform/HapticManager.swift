#if canImport(UIKit)
import UIKit
#endif

enum GolfHapticEffect: Sendable { case impact, cup, selection }

@MainActor
protocol HapticOutput: AnyObject {
    func impact(intensity: Double)
    func selection()
}

/// Haptics supplement visible shot/result feedback; play never depends on hardware.
@MainActor
final class HapticManager {
    var isEnabled: Bool
    private let output: any HapticOutput

    init(isEnabled: Bool = true, output: (any HapticOutput)? = nil) {
        self.isEnabled = isEnabled
        self.output = output ?? DeviceHapticOutput()
    }

    func play(_ effect: GolfHapticEffect) {
        guard isEnabled else { return }
        switch effect {
        case .impact: output.impact(intensity: 0.35)
        case .cup: output.impact(intensity: 0.6)
        case .selection: output.selection()
        }
    }
}

/// UIKit feedback gracefully becomes a no-op on devices without supported hardware.
@MainActor
private final class DeviceHapticOutput: HapticOutput {
    #if canImport(UIKit)
    private let impactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    #endif

    func impact(intensity: Double) {
        #if canImport(UIKit)
        guard UIApplication.shared.applicationState == .active else { return }
        impactGenerator.impactOccurred(intensity: intensity)
        #endif
    }

    func selection() {
        #if canImport(UIKit)
        guard UIApplication.shared.applicationState == .active else { return }
        selectionGenerator.selectionChanged()
        #endif
    }
}
