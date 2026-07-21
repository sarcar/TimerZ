import Foundation
import SwiftData

@Model
final class IntensitySession {
    var id: UUID
    var sessionDate: Date
    var committedAt: Date
    var committedUntil: Date
    var durationSeconds: Int
    var completed: Bool
    var timeSpentSeconds: Int
    var distractionCount: Int
    var completedAt: Date

    init(
        committedAt: Date,
        committedUntil: Date,
        durationSeconds: Int,
        completed: Bool,
        timeSpentSeconds: Int,
        distractionCount: Int
    ) {
        self.id = UUID()
        self.sessionDate = Calendar.current.startOfDay(for: committedAt)
        self.committedAt = committedAt
        self.committedUntil = committedUntil
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.timeSpentSeconds = timeSpentSeconds
        self.distractionCount = distractionCount
        self.completedAt = Date()
    }
}
