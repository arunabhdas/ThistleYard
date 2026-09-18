import SwiftUI

struct RootView: View {
    let coordinator: AppCoordinator
    @Environment(PlayerStore.self) private var player

    var body: some View {
        NavigationStack {
            Group {
                switch coordinator.content {
                case .loading:
                    ProgressView("Opening the coast…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready(let course):
                    if player.loaded { MainMenuView(course: course) }
                    else { ProgressView("Opening your save…") }
                case .failed(let message):
                    ContentUnavailableView {
                        Label("A little delay", systemImage: "leaf")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again", action: coordinator.loadCourse)
                            .buttonStyle(GolfPrimaryButtonStyle())
                            .frame(maxWidth: 320)
                    }
                }
            }
            .background(GolfTheme.cream)
        }
        .task {
            if case .loading = coordinator.content { coordinator.loadCourse() }
        }
    }
}
