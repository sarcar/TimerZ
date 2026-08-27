import SwiftUI
import SwiftData

private struct ActiveTaskTimer: Identifiable {
    let id = UUID()
    let taskName: String?
    let seconds: Int
}

private enum TaskSort: String, CaseIterable, Identifiable {
    case name = "Name"
    case duration = "Duration"
    case recentlyUsed = "Recently Used"

    var id: String { rawValue }
}

struct TaskLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TimerTask]

    @State private var searchText = ""
    @State private var sort: TaskSort = .recentlyUsed
    @State private var showAddSheet = false
    @State private var editingTask: TimerTask?
    @State private var activeTaskTimer: ActiveTaskTimer?

    private var filteredAndSortedTasks: [TimerTask] {
        let filtered = searchText.isEmpty
            ? tasks
            : tasks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        switch sort {
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .duration:
            return filtered.sorted { $0.durationMinutes < $1.durationMinutes }
        case .recentlyUsed:
            return filtered.sorted {
                switch ($0.lastUsedAt, $1.lastUsedAt) {
                case let (a?, b?): return a > b
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return $0.createdAt > $1.createdAt
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Yet",
                        systemImage: "checklist",
                        description: Text("Add a task with its own timer, like \"Quick cook - 25 min\".")
                    )
                } else {
                    List {
                        ForEach(filteredAndSortedTasks) { task in
                            taskRow(task)
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(TaskSort.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            TaskFormView { name, minutes in
                let task = TimerTask(name: name, durationMinutes: minutes)
                modelContext.insert(task)
                try? modelContext.save()
            }
        }
        .sheet(item: $editingTask) { task in
            TaskFormView(task: task) { name, minutes in
                task.name = name
                task.durationMinutes = minutes
                try? modelContext.save()
            }
        }
        .fullScreenCover(item: $activeTaskTimer) { timer in
            TimerSessionView(
                durationSeconds: timer.seconds,
                taskName: timer.taskName,
                onDismiss: { activeTaskTimer = nil },
                onDismissAndAmend: nil,
                onDismissAndStartNext: { seconds in
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        activeTaskTimer = ActiveTaskTimer(taskName: nil, seconds: seconds)
                    }
                }
            )
            .id(timer.id)
        }
    }

    private func taskRow(_ task: TimerTask) -> some View {
        Button {
            task.lastUsedAt = Date()
            try? modelContext.save()
            activeTaskTimer = ActiveTaskTimer(taskName: task.name, seconds: task.durationMinutes * 60)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("\(task.durationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editingTask = task
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(task)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editingTask = task
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}
