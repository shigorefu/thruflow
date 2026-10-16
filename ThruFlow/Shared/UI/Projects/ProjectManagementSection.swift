#if !os(watchOS)
import SwiftData
import SwiftUI

/// Saved Area only: managing Projects never commits the surrounding Area draft.
struct ProjectManagementSection<TaskEditor: View>: View {
    @Query(sort: \Project.createdAt) private var projects: [Project]
    let area: Area
    private let taskEditor: (Todo?, Project) -> TaskEditor
    @State private var showingCreation = false
    @State private var selectedProject: Project?

    init(area: Area, @ViewBuilder taskEditor: @escaping (Todo?, Project) -> TaskEditor) {
        self.area = area
        self.taskEditor = taskEditor
    }

    private var areaProjects: [Project] {
        projects.filter { $0.area?.id == area.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(String(localized: "プロジェクト"), systemImage: "folder")
                    .font(.headline)
                Spacer()
                if !area.isArchived && !DefaultAreas.isTaskInbox(area) {
                    Button { showingCreation = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "プロジェクトを追加"))
                }
            }
            if areaProjects.isEmpty {
                Text(String(localized: "プロジェクトはありません"))
                    .foregroundStyle(.secondary)
            }
            projectRows(completed: false)
            if areaProjects.contains(where: \.isCompleted) {
                Text(String(localized: "完了したプロジェクト"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                projectRows(completed: true)
            }
        }
        .sheet(isPresented: $showingCreation) {
            ProjectEditorView(area: area)
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project, taskEditor: taskEditor)
        }
    }

    private func projectRows(completed: Bool) -> some View {
        ForEach(areaProjects.filter { $0.isCompleted == completed }) { project in
            Button { selectedProject = project } label: {
                HStack {
                    Image(systemName: project.isCompleted ? "checkmark.circle" : "folder")
                    Text(project.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ProjectDetailView<TaskEditor: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Todo.sortIndex) private var todos: [Todo]
    let project: Project
    let taskEditor: (Todo?, Project) -> TaskEditor
    @State private var isEditingProject = false
    @State private var taskRoute: ProjectTaskRoute?
    @State private var saveError: String?

    private var projectTodos: [Todo] {
        todos.filter { $0.project?.id == project.id && !$0.isDeleted && !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let notes = project.notes, !notes.isEmpty {
                    Section(String(localized: "メモ")) { Text(notes) }
                }
                Section(String(localized: "タスク")) {
                    ForEach(projectTodos) { todo in
                        Button { taskRoute = ProjectTaskRoute(todo: todo) } label: {
                            Label(TodoDisplay.title(for: todo), systemImage: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        }
                    }
                    if !project.isCompleted && project.area?.isArchived == false {
                        Button(String(localized: "タスクを追加"), systemImage: "plus") {
                            taskRoute = ProjectTaskRoute(todo: nil)
                        }
                    }
                }
                Section {
                    Button(String(localized: project.isCompleted ? "プロジェクトを再開" : "プロジェクトを完了")) {
                        do {
                            try ProjectEditingService().setCompleted(
                                !project.isCompleted, for: project, modelContext: modelContext
                            )
                        } catch {
                            saveError = String(localized: "記録を保存できませんでした。")
                        }
                    }
                }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .formStyle(.grouped)
            .navigationTitle(project.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "プロジェクトを編集")) { isEditingProject = true }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
#endif
        .sheet(isPresented: $isEditingProject) {
            if let area = project.area { ProjectEditorView(area: area, project: project) }
        }
        .sheet(item: $taskRoute) { route in
            taskEditor(route.todo, project)
        }
    }
}

private struct ProjectTaskRoute: Identifiable {
    let id = UUID()
    let todo: Todo?
}

private struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let area: Area
    let project: Project?
    @State private var name: String
    @State private var notes: String
    @State private var saveError: String?

    init(area: Area, project: Project? = nil) {
        self.area = area
        self.project = project
        // One-time editor draft; cancellation does not change persisted models.
        _name = State(initialValue: project?.name ?? "")
        _notes = State(initialValue: project?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "プロジェクト名"), text: $name)
                TextField(String(localized: "メモ"), text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: project == nil ? "プロジェクトを追加" : "プロジェクトを編集"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "保存"), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 420, minHeight: 280)
#endif
    }

    private func save() {
        do {
            _ = try ProjectEditingService().save(
                name: name, notes: notes, area: area, editing: project, modelContext: modelContext
            )
            dismiss()
        } catch {
            saveError = String(localized: "記録を保存できませんでした。")
        }
    }
}
#endif
