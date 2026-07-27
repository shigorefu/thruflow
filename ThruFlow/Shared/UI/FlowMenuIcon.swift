import SwiftUI

struct FlowMenuIcon: View {
    var width: CGFloat = 20

    var body: some View {
        Image("FlowMenuBarIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: width * 0.7)
    }
}
