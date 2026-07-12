import Observation

/// In-memory app state. Not persisted — resets to defaults on every cold launch.
@Observable
final class AppState {
    var testModeEnabled = false
}
