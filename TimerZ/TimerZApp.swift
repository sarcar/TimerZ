import SwiftUI
import SwiftData

@main
struct TimerZApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Session.self)
    }
}
