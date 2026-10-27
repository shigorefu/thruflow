import SwiftData
import SwiftUI

struct FlowMemoProjectPicker: View {
    @Query(sort: \Project.createdAt) private var projects: [Project]
    let todo: Todo?
    @Binding var selection: Project?

    var body: some View {
        if todo?.project == nil && (selection != nil || !FlowMemoProjectPolicy.choices(for: todo, projects: projects).isEmpty) {
            TaskProjectPicker(area: todo?.area, selection: $selection, currentProject: selection)
#if !os(watchOS)
                .pickerStyle(.menu)
#endif
        }
    }
}
