import Observation

@Observable
final class AppState {
    #if targetEnvironment(simulator)
    var testModeEnabled = true
    #else
    var testModeEnabled = false
    #endif
}
