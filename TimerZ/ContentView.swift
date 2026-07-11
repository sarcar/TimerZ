import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TimersView()
                .tabItem { Label("Timers", systemImage: "timer") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
