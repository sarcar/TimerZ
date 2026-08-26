import Foundation
import SwiftData

@Model
final class TimerTask {
    var id: UUID
    var name: String
    var durationMinutes: Int
    var createdAt: Date
    var lastUsedAt: Date?

    init(name: String, durationMinutes: Int) {
        self.id = UUID()
        self.name = name
        self.durationMinutes = durationMinutes
        self.createdAt = Date()
        self.lastUsedAt = nil
    }
}
