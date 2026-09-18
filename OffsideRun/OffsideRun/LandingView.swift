import SwiftUI

/// Explains the game before the first run: controls, the three obstacles and
/// the single move that clears each one, what to collect, and how to win.
struct LandingView: View {
    let onStart: () -> Void

    private let ink = Color(red: 0.09, green: 0.14, blue: 0.13)
    private let parchment = Color(red: 0.96, green: 0.89, blue: 0.65)
    private let jumpColor = Color(red: 0.98, green: 0.68, blue: 0.22)
    private let slideColor = Color(red: 0.42, green: 0.72, blue: 0.94)
    private let swingColor = Color(red: 0.95, green: 0.42, blue: 0.50)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.39, blue: 0.38),
                    Color(red: 0.12, green: 0.24, blue: 0.24),
                    Color(red: 0.08, green: 0.12, blue: 0.11),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        section("Obstacles") {
                            Text("Every obstacle shows a badge as it gets close. The badge is the one move that clears it.")
                                .font(.callout)
                                .foregroundStyle(parchment.opacity(0.85))
                            obstacleRow(badge: "▲ JUMP", color: jumpColor, name: "Log", how: "Swipe up to jump over it.")
                            obstacleRow(badge: "▼ SLIDE", color: slideColor, name: "Arch", how: "Swipe down to slide under it.")
                            obstacleRow(badge: "✕ SWING", color: swingColor, name: "Maskling", how: "Tap to swing your blade at it.")
                        }
                        section("Controls") {
                            controlRow(symbol: "arrow.left.and.right", text: "Swipe left or right to change lanes.")
                            controlRow(symbol: "arrow.up", text: "Swipe up to jump.")
                            controlRow(symbol: "arrow.down", text: "Swipe down to slide.")
                            controlRow(symbol: "hand.tap", text: "Tap anywhere to swing.")
                        }
                        section("Collect") {
                            collectRow(color: jumpColor, name: "Crowns", text: "Score. Grab as many as you can.")
                            collectRow(color: Color(red: 0.30, green: 0.52, blue: 0.82), name: "Rune shards", text: "Find all four to open the Forest Gate.")
                            collectRow(color: Color(red: 0.92, green: 0.20, blue: 0.20), name: "Hearts", text: "Restore a lost heart. You start with three.")
                        }
                        section("Goal") {
                            Text("Collect all four rune shards and run past 900 m to clear the Forest Gate. Lose all three hearts and the bramble catches you.")
                                .font(.callout)
                                .foregroundStyle(parchment.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }

                startButton
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Offside Run")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(parchment)
            Text("A cozy forest dash. Read the badge, make the move, keep your hearts.")
                .font(.body)
                .foregroundStyle(parchment.opacity(0.85))
        }
    }

    private var startButton: some View {
        Button(action: onStart) {
            Text("Start Run")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(parchment, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Starts the game")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(parchment.opacity(0.6))
            content()
        }
    }

    private func obstacleRow(badge: String, color: Color, name: String, how: String) -> some View {
        HStack(spacing: 14) {
            Text(badge)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(color, in: Capsule())
                .overlay(Capsule().stroke(ink, lineWidth: 2))
                .frame(width: 104, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(parchment)
                Text(how)
                    .font(.footnote)
                    .foregroundStyle(parchment.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func controlRow(symbol: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(parchment)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(text)
                .font(.callout)
                .foregroundStyle(parchment.opacity(0.9))
            Spacer(minLength: 0)
        }
    }

    private func collectRow(color: Color, name: String, text: String) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color)
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                .frame(width: 18, height: 18)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(parchment)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(parchment.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    LandingView(onStart: {})
}
