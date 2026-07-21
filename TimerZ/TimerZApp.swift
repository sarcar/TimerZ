import SwiftUI
import SwiftData

@main
struct TimerZApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .modelContainer(for: [Session.self, IntensitySession.self])
    }
}
