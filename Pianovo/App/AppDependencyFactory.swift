import SwiftData

@MainActor
enum AppDependencyFactory {
    static func makeProductionDependencies(
        makeLibraryContainer: @MainActor () throws -> ModelContainer = { try LibraryModelContainerFactory.makeContainer() },
        makeContainer: @MainActor () throws -> ModelContainer = { try PracticeHistoryModelContainerFactory.makeContainer() }
    ) -> AppDependencies {
        // The stores bootstrap independently: neither failure selects a temporary production fallback.
        let progressContainer = try? makeContainer()
        let libraryContainer = try? makeLibraryContainer()
        let progress = progressContainer.map { SwiftDataPracticeHistoryRepository(context: ModelContext($0)) }
        let library = libraryContainer.map { SwiftDataLibraryExerciseRepository(container: $0) }
        let templates = libraryContainer.map { SwiftDataLibraryTemplateRepository(container: $0) }
        let programmes = libraryContainer.map { SwiftDataLibraryProgrammeRepository(container: $0) }
        let learnerProgrammes = libraryContainer.map { SwiftDataLearnerProgrammeRepository(container: $0) }
        let notes = libraryContainer.map { SwiftDataPrivateLearnerNoteRepository(container: $0) }
        return AppDependencies(
            progressRepository: progress, practiceHistoryRepository: progress,
            referenceMaterialResolver: PianovoReferenceMaterialCatalogue.resolver(),
            clock: SystemPracticeClock(), localContextProvider: SystemPracticeLocalContextProvider(),
            persistenceStatus: progress == nil ? .unavailable : .available,
            retainedModelContainer: progressContainer, libraryRepository: library,
            retainedLibraryContainer: libraryContainer, templateRepository: templates, programmeTemplateRepository: programmes, learnerProgrammeRepository: learnerProgrammes, privateNoteRepository: notes
        )
    }
}
