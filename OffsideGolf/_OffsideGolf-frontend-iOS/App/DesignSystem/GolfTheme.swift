import SwiftUI

enum GolfTheme {
    static let pine = Color(red: 0.07, green: 0.25, blue: 0.21)
    static let cream = Color(red: 0.96, green: 0.95, blue: 0.89)
    static let mist = Color(red: 0.87, green: 0.91, blue: 0.85)
    static let secondary = Color(red: 0.28, green: 0.38, blue: 0.32)
    static let clay = Color(red: 0.65, green: 0.28, blue: 0.20)
}

struct GolfPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(18)
            .foregroundStyle(GolfTheme.cream)
            .background(GolfTheme.pine.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct CourseFacts: View {
    let par: Int
    let yards: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) { facts }
            VStack(alignment: .leading, spacing: 8) { facts }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(GolfTheme.secondary)
    }

    @ViewBuilder private var facts: some View {
        Label("Par \(par)", systemImage: "flag")
        Label("\(yards.formatted()) yd", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            .accessibilityLabel("\(yards) yards")
    }
}
