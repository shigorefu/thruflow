import SwiftData
import SwiftUI

/// Optional project selection is shared by the native Task creation/editing surfaces.
struct TaskProjectPicker: View {
    @Query(sort: \Project.createdAt) private var projects: [Project]
    let area: Area?
    @Binding var selection: Project?
    var currentProject: Project? = nil
    var showsDivider = false

    private var choices: [Project] {
        var result = projects.filter {
            $0.area?.id == area?.id && area != nil && $0.isAvailableForNewTasks
        }
        for retained in [currentProject, selection].compactMap({ $0 }) {
            if area != nil, retained.area?.id == area?.id,
               !result.contains(where: { $0.id == retained.id }) {
                result.append(retained)
            }
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        if !choices.isEmpty {
            if showsDivider { Divider() }
            Picker(String(localized: "対象プロジェクト"), selection: selectedID) {
                Text(String(localized: "プロジェクトなし")).tag(UUID?.none)
                ForEach(choices) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }
        }
    }

    private var selectedID: Binding<UUID?> {
        Binding(
            get: { selection?.id },
            set: { id in selection = choices.first { $0.id == id } }
        )
    }
}
