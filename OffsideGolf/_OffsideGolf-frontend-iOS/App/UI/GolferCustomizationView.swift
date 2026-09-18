import SwiftUI
import OffsideGolfCore

struct GolferCustomizationView: View {
    @Environment(PlayerStore.self) private var player
    var body: some View {
        Form {
            Section("Your golfer") {
                Text("A little personality for the fairway.").font(.title3)
                Picker("Skin palette",selection: binding(\.skinPalette)) {
                    ForEach(0..<4) { Text(["Warm sand","Golden","Copper","Deep brown"][$0]).tag($0) }
                }
                Picker("Hair",selection: binding(\.hairStyle)) {
                    ForEach(0..<3) { Text(["Short","Soft curl","Side sweep"][$0]).tag($0) }
                }
                Picker("Outfit",selection: binding(\.outfitPalette)) {
                    ForEach(0..<4) { Text(["Meadow green","Coastal blue","Terracotta","Lavender"][$0]).tag($0) }
                }
            }
            Text("All styles are yours from the start.").foregroundStyle(GolfTheme.secondary)
        }.navigationTitle("Your golfer")
    }
    private func binding(_ key: WritableKeyPath<GolferAppearance,Int>) -> Binding<Int> {
        Binding(get: { player.appearance[keyPath:key] },set: { value in
            var appearance = player.appearance;appearance[keyPath:key] = value;player.updateAppearance(appearance)
        })
    }
}
