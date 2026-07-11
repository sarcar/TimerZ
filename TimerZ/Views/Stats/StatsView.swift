import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Session.completedAt, order: .reverse) private var sessions: [Session]

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "chart.bar",
                        description: Text("Start a timer to see your stats here.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            statsGrid
                            chartSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: - Computed stats

    private var totalWins: Int { sessions.filter { $0.isWin }.count }
    private var totalLosses: Int { sessions.filter { !$0.isWin }.count }

    private var winRate: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(totalWins) / Double(sessions.count) * 100
    }

    private var currentStreak: Int {
        var streak = 0
        for session in sessions {
            if session.isWin { streak += 1 } else { break }
        }
        return streak
    }

    private var bestStreak: Int {
        var best = 0
        var current = 0
        for session in sessions.reversed() {
            if session.isWin {
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
        let wins: Int
        let losses: Int
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
                wins: daySessions.filter { $0.isWin }.count,
                losses: daySessions.filter { !$0.isWin }.count
            )
        }
    }

    private var chartEntries: [ChartEntry] {
        last7Days.flatMap { day in [
            ChartEntry(date: day.id, type: "Win", count: day.wins),
            ChartEntry(date: day.id, type: "Loss", count: day.losses)
        ]}
    }

    // MARK: - Sub-views

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Time")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Sessions", value: "\(sessions.count)", color: .blue)
                StatCard(title: "Win Rate",  value: String(format: "%.0f%%", winRate), color: .green)
                StatCard(title: "Streak",    value: "\(currentStreak)", color: .orange)
                StatCard(title: "Best Streak", value: "\(bestStreak)", color: .purple)
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
            .chartForegroundStyleScale(["Win": Color.green, "Loss": Color.red])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .frame(height: 200)
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
