import SwiftUI
import SwiftData
import Charts

struct IntensityStatsView: View {
    @Query(sort: \IntensitySession.completedAt, order: .reverse) private var sessions: [IntensitySession]

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Intensity")
                        .font(.largeTitle.bold())
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    if sessions.isEmpty {
                        ContentUnavailableView(
                            "No Intensity Sessions Yet",
                            systemImage: "flame",
                            description: Text("Commit to an hour of undistracted focus to see your stats here.")
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            statsGrid
                            chartSection
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Computed stats

    private var completedSessions: [IntensitySession] { sessions.filter { $0.completed } }
    private var brokenSessions: [IntensitySession] { sessions.filter { !$0.completed } }

    private var completionRate: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(completedSessions.count) / Double(sessions.count) * 100
    }

    private var totalIntensityMinutes: Int {
        completedSessions.reduce(0) { $0 + $1.timeSpentSeconds } / 60
    }

    private var totalDistractions: Int {
        sessions.reduce(0) { $0 + $1.distractionCount }
    }

    private func formatHours(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var currentStreak: Int {
        var streak = 0
        for session in sessions {
            if session.completed { streak += 1 } else { break }
        }
        return streak
    }

    private var bestStreak: Int {
        var best = 0
        var current = 0
        for session in sessions.reversed() {
            if session.completed {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    // MARK: - Chart data

    private struct DayStats: Identifiable {
        let id: Date
        let completed: Int
        let broken: Int
    }

    private struct ChartEntry: Identifiable {
        let id = UUID()
        let date: Date
        let type: String
        let count: Int
    }

    private var last7Days: [DayStats] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let daySessions = sessions.filter { calendar.isDate($0.sessionDate, inSameDayAs: date) }
            return DayStats(
                id: date,
                completed: daySessions.filter { $0.completed }.count,
                broken: daySessions.filter { !$0.completed }.count
            )
        }
    }

    private var chartEntries: [ChartEntry] {
        last7Days.flatMap { day in [
            ChartEntry(date: day.id, type: "Completed", count: day.completed),
            ChartEntry(date: day.id, type: "Broken", count: day.broken)
        ]}
    }

    // MARK: - Sub-views

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Time")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Sessions", value: "\(sessions.count)", color: .indigo)
                StatCard(title: "Completion Rate", value: String(format: "%.0f%%", completionRate), color: .green)
                StatCard(title: "Streak", value: "\(currentStreak)", color: .orange)
                StatCard(title: "Best Streak", value: "\(bestStreak)", color: .purple)
                StatCard(title: "Intensity Hours", value: formatHours(totalIntensityMinutes), color: .teal)
                StatCard(title: "Distractions Logged", value: "\(totalDistractions)", color: .red)
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)
            Chart(chartEntries) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Count", entry.count)
                )
                .foregroundStyle(by: .value("Result", entry.type))
            }
            .chartForegroundStyleScale(["Completed": Color.green, "Broken": Color.red])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .frame(height: 200)
        }
    }
}
