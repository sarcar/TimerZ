import SwiftUI

struct TimersPagerView: View {
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            TimersView()
                .tag(0)
            IntensityModeView()
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}
