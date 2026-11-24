#if os(macOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AreaReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedAreaID: UUID?
    @Binding var dropTargetID: UUID?
    let move: (UUID, UUID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedAreaID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedAreaID, draggedAreaID != targetID else { return }
        dropTargetID = targetID
        withAnimation(.easeInOut(duration: 0.16)) {
            move(draggedAreaID, targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetID == targetID {
            dropTargetID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedAreaID = nil
        dropTargetID = nil
        return true
    }
}

struct AreaGroupReorderDropDelegate: DropDelegate {
    let targetType: AreaType
    @Binding var draggedGroupType: AreaType?
    @Binding var dropTargetGroupType: AreaType?
    let move: (AreaType, AreaType) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedGroupType != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedGroupType, draggedGroupType != targetType else { return }
        dropTargetGroupType = targetType
        withAnimation(.easeInOut(duration: 0.16)) {
            move(draggedGroupType, targetType)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetGroupType == targetType {
            dropTargetGroupType = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedGroupType = nil
        dropTargetGroupType = nil
        return true
    }
}
#endif
