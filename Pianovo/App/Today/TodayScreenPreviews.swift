#if DEBUG
import SwiftUI

private enum TodayPreviewScenario {
    case notStarted
    case firstDay
    case recovery
    case partialMaterials
    case persistenceFailure
}

private struct TodayPreview: View {
    let scenario: TodayPreviewScenario
    @State private var model: TodayViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    TodayScreen(viewModel: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Today")
        }
        .task {
            guard model == nil else { return }
            let clock = FixedPracticeClock(now: Date(timeIntervalSince1970: 1_790_496_000))
            let context = FixedPracticeLocalContextProvider(
                timeZone: TimeZone(identifier: "Europe/London")!, calendarIdentifier: .gregorian
            )
            if scenario == .persistenceFailure {
                let previewModel = TodayViewModel(dependencies: .unavailablePersistence(
                    clock: clock, localContextProvider: context
                ))
                await previewModel.loadIfNeeded()
                model = previewModel
                return
            }

            let repository = InMemoryPracticeHistoryRepository()
            let seed = PianovoProgrammeSeedData.twelveWeekProgramme()
            if scenario != .notStarted, let week = seed.programme.weeks.first,
               let day = week.days.first(where: { scenario == .recovery ? $0.kind == .recoveryReflection : $0.dayNumber == 1 }) {
                let temporalContext = PracticeTemporalContext(clock: clock, localContextProvider: context)
                do {
                    try await repository.saveActiveProgress(ActiveProgrammeProgress(
                        programme: ProgrammeDefinitionReference(programmeID: seed.programme.id, programmeVersion: 1),
                        currentWeekID: week.id, currentDayID: day.id,
                        updatedAt: PracticeTimestamp(instant: temporalContext.now, localDay: temporalContext.localDay)
                    ))
                } catch {
                    assertionFailure("Invalid deterministic preview progress")
                }
            }
            let resolver = ReferenceMaterialResolver(
                catalogue: PianovoReferenceMaterialCatalogue.catalogue(),
                sourceMappings: PianovoReferenceMaterialCatalogue.sourceMappings,
                availabilityProvider: PreviewMaterialAvailability(partial: scenario == .partialMaterials)
            )
            let previewModel = TodayViewModel(dependencies: .preview(
                repository: repository, clock: clock, localContextProvider: context,
                referenceMaterialResolver: resolver
            ))
            await previewModel.loadIfNeeded()
            model = previewModel
        }
    }
}

private struct PreviewMaterialAvailability: DocumentAvailabilityProviding {
    let partial: Bool

    func availability(for material: ReferenceMaterial) -> DocumentAvailability {
        if partial && !material.components.contains(where: { $0.role == .prima }) {
            return .available(DocumentAccessReference("preview-only")!)
        }
        return .unavailable(reason: .notImported)
    }
}

#Preview("Not started · iPhone", traits: .fixedLayout(width: 393, height: 852)) {
    TodayPreview(scenario: .notStarted)
}

#Preview("Week 1 Day 1 · iPad", traits: .fixedLayout(width: 1100, height: 820)) {
    TodayPreview(scenario: .firstDay)
}

#Preview("Recovery day · iPhone", traits: .fixedLayout(width: 393, height: 852)) {
    TodayPreview(scenario: .recovery)
}

#Preview("Partial material availability · iPad", traits: .fixedLayout(width: 1100, height: 820)) {
    TodayPreview(scenario: .partialMaterials)
}

#Preview("Persistence unavailable · iPhone", traits: .fixedLayout(width: 393, height: 852)) {
    TodayPreview(scenario: .persistenceFailure)
}

#Preview("Large text · iPhone", traits: .fixedLayout(width: 393, height: 852)) {
    TodayPreview(scenario: .firstDay)
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
