import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var sessionDate: Date
    var durationSeconds: Int
    var isWin: Bool
    var completedAt: Date

    init(durationSeconds: Int, isWin: Bool) {
        self.id = UUID()
        let now = Date()
        self.sessionDate = Calendar.current.startOfDay(for: now)
        self.durationSeconds = durationSeconds
        self.isWin = isWin
        self.completedAt = now
    }
}
