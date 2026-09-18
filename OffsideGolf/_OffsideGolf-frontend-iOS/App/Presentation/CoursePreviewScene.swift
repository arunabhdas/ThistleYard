import SwiftUI

/// A mood illustration; authored gameplay geometry is rendered by GameScene.
struct CourseIllustration: View {
    let seed: Int
    var body: some View {
        GeometryReader { geometry in
            Image("CoastMenu")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width,height: geometry.size.height)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel("Painted coastal meadows, wildflowers and a distant lighthouse")
        .accessibilityIdentifier("course.illustration")
    }
}
