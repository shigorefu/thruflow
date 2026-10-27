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

struct ProjectDetailView<TaskEditor: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
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
                Section(String(localized: "プロジェクトの習慣")) {
                    Button(String(localized: "プロジェクトを編集")) { isEditingProject = true }
                    ForEach(projectTodos.filter(\.isHabitOccurrence)) { todo in
                        taskRow(todo)
                    }
                }
                Section(String(localized: "タスク")) {
                    ForEach(projectTodos.filter { !$0.isHabitOccurrence }) { todo in
                        taskRow(todo)
                    }
                }
                Section {
                    Button(String(localized: project.isCompleted ? "プロジェクトを再開" : "プロジェクトを完了")) {
                        do {
                            try ProjectEditingService(calendar: calendar, dayBoundary: dayBoundary).setCompleted(
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
    private func taskRow(_ todo: Todo) -> some View {
        Button { taskRoute = ProjectTaskRoute(todo: todo) } label: {
            HStack {
                Label(TodoDisplay.taskTitle(for: todo), systemImage: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                Spacer()
                if todo.isHabitOccurrence, let date = todo.scheduledDate {
                    Text(date, format: .dateTime.month().day()).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(todo.isCompleted ? .secondary : .primary)
        }
    }
}

private struct ProjectTaskRoute: Identifiable {
    let id = UUID()
    let todo: Todo?
}

struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    let area: Area
    let project: Project?
    @State private var name: String
    @State private var habit: ProjectHabitSettings
    @State private var saveError: String?

    init(area: Area, project: Project? = nil) {
        self.area = area
        self.project = project
        // One-time editor draft; cancellation does not change persisted models.
        _name = State(initialValue: project?.name ?? "")
        _habit = State(initialValue: project?.habitSettings ?? ProjectHabitSettings())
    }

    var body: some View {
        NavigationStack {
            editorContent
            .navigationTitle(String(localized: project == nil ? "プロジェクトを追加" : "プロジェクトを編集"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
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
        .frame(minWidth: 500, idealWidth: 560, minHeight: 380, idealHeight: 540)
#endif
    }

    @ViewBuilder
    private var editorContent: some View {
#if os(macOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EditorSectionCard { identityHeader }
                ProjectHabitFormSection(settings: $habit)
                if let saveError {
                    EditorSectionCard { Text(saveError).foregroundStyle(.red) }
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
#else
        Form {
            Section { identityHeader }
            ProjectHabitFormSection(settings: $habit)
            if let saveError { Section { Text(saveError).foregroundStyle(.red) } }
        }
#endif
    }

    private var identityHeader: some View {
        HStack(spacing: identitySpacing) {
            Text(area.symbolName)
#if os(macOS)
                .font(.system(size: 48))
                .frame(width: 76, height: 76)
#else
                .font(.largeTitle)
                .frame(width: 58, height: 58)
#endif
                .background(Color(hex: area.colorHex).opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                TextField(String(localized: "プロジェクト名"), text: $name)
                    .font(.title3.weight(.semibold))
                    .textFieldStyle(.plain)
                Text(area.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var identitySpacing: CGFloat {
#if os(macOS)
        18
#else
        12
#endif
    }

    private func save() {
        do {
            _ = try ProjectEditingService(calendar: calendar, dayBoundary: dayBoundary).save(
                name: name, notes: project?.notes ?? "", area: area, editing: project, habit: habit, modelContext: modelContext
            )
            dismiss()
        } catch let error as ProjectEditingError {
            saveError = error.localizedDescription
        } catch {
            saveError = String(localized: "記録を保存できませんでした。")
        }
    }
}
#endif
