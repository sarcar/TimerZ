import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Session.completedAt, order: .reverse) private var sessions: [Session]

    private let calendar = Calendar.current
    @State private var tatRange: TATRange = .week

    private enum TATRange: String, CaseIterable {
        case week = "7D", month = "30D", allTime = "All"
    }

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
                            tatSection
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

    private var tatToday: Int {
        let today = calendar.startOfDay(for: Date())
        return sessions
            .filter { $0.isWin && calendar.isDate($0.sessionDate, inSameDayAs: today) }
            .reduce(0) { $0 + $1.timeSpentSeconds } / 60
    }

    private var prTAT: Int {
        let wins = sessions.filter { $0.isWin }
        guard !wins.isEmpty else { return 0 }
        let days = Set(wins.map { calendar.startOfDay(for: $0.sessionDate) })
        return days.map { day in
            wins.filter { calendar.isDate($0.sessionDate, inSameDayAs: day) }
                .reduce(0) { $0 + $1.timeSpentSeconds }
        }.max().map { $0 / 60 } ?? 0
    }

    private func formatTAT(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

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
                StatCard(title: "Sessions",   value: "\(sessions.count)", color: .blue)
                StatCard(title: "Win Rate",   value: String(format: "%.0f%%", winRate), color: .green)
                StatCard(title: "Streak",     value: "\(currentStreak)", color: .orange)
                StatCard(title: "Best Streak",value: "\(bestStreak)", color: .purple)
                StatCard(title: "TAT Today",  value: formatTAT(tatToday), color: .teal)
                StatCard(title: "PR TAT",     value: formatTAT(prTAT), color: .indigo)
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

    // MARK: - TAT

    private struct TATDay: Identifiable {
        let id: Date
        let minutes: Int
    }

    private var tatDays: [TATDay] {
        let today = calendar.startOfDay(for: Date())
        let wins = sessions.filter { $0.isWin }

        func mins(for date: Date) -> Int {
            wins.filter { calendar.isDate($0.sessionDate, inSameDayAs: date) }
                .reduce(0) { $0 + $1.timeSpentSeconds } / 60
        }

        switch tatRange {
        case .week:
            return (0..<7).reversed().map { i in
                let d = calendar.date(byAdding: .day, value: -i, to: today)!
                return TATDay(id: d, minutes: mins(for: d))
            }
        case .month:
            return (0..<30).reversed().map { i in
                let d = calendar.date(byAdding: .day, value: -i, to: today)!
                return TATDay(id: d, minutes: mins(for: d))
            }
        case .allTime:
            guard let first = sessions.map({ $0.sessionDate }).min() else { return [] }
            let firstDay = calendar.startOfDay(for: first)
            let count = max(1, calendar.dateComponents([.day], from: firstDay, to: today).day! + 1)
            return (0..<count).map { i in
                let d = calendar.date(byAdding: .day, value: i, to: firstDay)!
                return TATDay(id: d, minutes: mins(for: d))
            }
        }
    }

    private var tatTotalString: String {
        formatTAT(tatDays.reduce(0) { $0 + $1.minutes })
    }

    private var tatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TAT")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $tatRange) {
                    ForEach(TATRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            Text(tatTotalString)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.purple)

            Chart(tatDays) { day in
                BarMark(
                    x: .value("Day", day.id, unit: .day),
                    y: .value("Minutes", day.minutes)
                )
                .foregroundStyle(.purple)
            }
            .chartXAxis {
                if tatRange == .week {
                    AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                } else {
                    AxisMarks { _ in AxisValueLabel() }
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
