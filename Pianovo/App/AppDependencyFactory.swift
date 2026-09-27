import SwiftData

@MainActor
enum AppDependencyFactory {
    static func makeProductionDependencies(
        makeContainer: @MainActor () throws -> ModelContainer = {
            try PracticeHistoryModelContainerFactory.makeContainer()
        }
    ) -> AppDependencies {
        do {
            let container = try makeContainer()
            let repository = SwiftDataPracticeHistoryRepository(context: ModelContext(container))
            return AppDependencies(
                progressRepository: repository,
                practiceHistoryRepository: repository,
                referenceMaterialResolver: PianovoReferenceMaterialCatalogue.resolver(),
                clock: SystemPracticeClock(),
                localContextProvider: SystemPracticeLocalContextProvider(),
                persistenceStatus: .available,
                retainedModelContainer: container
            )
        } catch {
            return .unavailablePersistence()
        }
    }
}
