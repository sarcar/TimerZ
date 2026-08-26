import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TimersPagerView()
                .tabItem { Label("Timers", systemImage: "timer") }

            TaskLibraryView()
                .tabItem { Label("Tasks", systemImage: "checklist") }

            StatsPagerView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
