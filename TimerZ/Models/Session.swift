import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var sessionDate: Date
    var durationSeconds: Int
    var isWin: Bool
    var completedAt: Date
    var timeSpentSeconds: Int = 0
    var accruedSeconds: Int = 0

    init(durationSeconds: Int, isWin: Bool, timeSpentSeconds: Int = 0, accruedSeconds: Int = 0) {
        self.id = UUID()
        let now = Date()
        self.sessionDate = Calendar.current.startOfDay(for: now)
        self.durationSeconds = durationSeconds
        self.isWin = isWin
        self.completedAt = now
        self.timeSpentSeconds = timeSpentSeconds
        self.accruedSeconds = accruedSeconds
    }
}
