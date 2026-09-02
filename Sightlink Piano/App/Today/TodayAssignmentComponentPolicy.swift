import Foundation

nonisolated struct TodayAssignmentComponentPolicy {
    func componentState(for component: ReferenceMaterialComponent) -> TodayReferenceMaterialComponentState {
        TodayReferenceMaterialComponentState(
            id: component.id,
            role: component.role,
            isRequiredForCompleteExercise: isRequiredForCompleteExercise(component),
            pdfKitPageIndex: component.pdfPageLocator?.pdfKitPageIndex,
            printedPageLabel: component.pdfPageLocator?.printedPageLabel
        )
    }

    private func isRequiredForCompleteExercise(_ component: ReferenceMaterialComponent) -> Bool {
        switch component.id {
        case ReferenceMaterialComponentID("beyer-op101-no-63-seconda"),
             ReferenceMaterialComponentID("beyer-op101-no-63-prima"):
            true
        default:
            component.requiredForCompleteExercise
        }
    }
}
