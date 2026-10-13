import Foundation
import SwiftData

@MainActor
struct AppDependencies {
    let privateNoteRepository: (any PrivateLearnerNoteRepository)?
    let learnerProgrammeRepository: (any LearnerProgrammeRepository)?
    let programmeTemplateRepository: (any LibraryProgrammeTemplateRepository)?
    let templateRepository: (any LibraryExerciseTemplateRepository)?
    let libraryRepository: (any LibraryExerciseRepository)?
    let libraryPersistenceStatus: AppPersistenceStatus
    private let retainedLibraryContainer: ModelContainer?
    let progressRepository: (any ProgrammeProgressRepository)?
    let practiceHistoryRepository: (any PracticeHistoryRepository)?
    let referenceMaterialResolver: any ReferenceMaterialResolving
    let clock: any PracticeClock
    let localContextProvider: any PracticeLocalContextProviding
    let persistenceStatus: AppPersistenceStatus
    private let retainedModelContainer: ModelContainer?

    init(
        progressRepository: (any ProgrammeProgressRepository)?,
        practiceHistoryRepository: (any PracticeHistoryRepository)?,
        referenceMaterialResolver: any ReferenceMaterialResolving,
        clock: any PracticeClock,
        localContextProvider: any PracticeLocalContextProviding,
        persistenceStatus: AppPersistenceStatus,
        retainedModelContainer: ModelContainer? = nil,
        libraryRepository: (any LibraryExerciseRepository)? = nil,
        retainedLibraryContainer: ModelContainer? = nil,
        templateRepository: (any LibraryExerciseTemplateRepository)? = nil,
        programmeTemplateRepository: (any LibraryProgrammeTemplateRepository)? = nil,
        learnerProgrammeRepository: (any LearnerProgrammeRepository)? = nil,
        privateNoteRepository: (any PrivateLearnerNoteRepository)? = nil
    ) {
        self.privateNoteRepository = privateNoteRepository
        self.learnerProgrammeRepository = learnerProgrammeRepository
        self.programmeTemplateRepository = programmeTemplateRepository
        self.templateRepository = templateRepository
        self.libraryRepository = libraryRepository
        self.libraryPersistenceStatus = libraryRepository == nil ? .unavailable : .available
        self.retainedLibraryContainer = retainedLibraryContainer
        self.progressRepository = progressRepository
        self.practiceHistoryRepository = practiceHistoryRepository
        self.referenceMaterialResolver = referenceMaterialResolver
        self.clock = clock
        self.localContextProvider = localContextProvider
        self.persistenceStatus = persistenceStatus
        self.retainedModelContainer = retainedModelContainer
    }

    var retainsLibraryModelContainer: Bool { retainedLibraryContainer != nil }

    var retainsProductionModelContainer: Bool {
        retainedModelContainer != nil
    }

    static func preview(
        repository: InMemoryPracticeHistoryRepository,
        clock: any PracticeClock = FixedPracticeClock(now: Date(timeIntervalSince1970: 0)),
        localContextProvider: any PracticeLocalContextProviding = FixedPracticeLocalContextProvider(
            timeZone: TimeZone(identifier: "Europe/London")!,
            calendarIdentifier: .gregorian
        ),
        referenceMaterialResolver: any ReferenceMaterialResolving = PianovoReferenceMaterialCatalogue.resolver()
    ) -> AppDependencies {
        let ownerID = LibraryOwnerID(rawValue: UUID())
        let exercises = InMemoryLibraryExerciseRepository(ownerID: ownerID)
        let programmes = InMemoryLibraryProgrammeTemplateRepository(ownerID: ownerID, exerciseRepository: exercises)
        return AppDependencies(
            progressRepository: repository,
            practiceHistoryRepository: repository,
            referenceMaterialResolver: referenceMaterialResolver,
            clock: clock,
            localContextProvider: localContextProvider,
            persistenceStatus: .available,
            libraryRepository: exercises,
            templateRepository: InMemoryLibraryExerciseTemplateRepository(ownerID: ownerID),
            programmeTemplateRepository: programmes,
            learnerProgrammeRepository: InMemoryLearnerProgrammeRepository(ownerID: ownerID, exercises: exercises, templates: programmes),
            privateNoteRepository: InMemoryPrivateLearnerNoteRepository()
        )
    }

    static func preview() -> AppDependencies {
        preview(repository: InMemoryPracticeHistoryRepository())
    }

    static func unavailablePersistence(
        clock: any PracticeClock = SystemPracticeClock(),
        localContextProvider: any PracticeLocalContextProviding = SystemPracticeLocalContextProvider(),
        referenceMaterialResolver: any ReferenceMaterialResolving = PianovoReferenceMaterialCatalogue.resolver()
    ) -> AppDependencies {
        AppDependencies(
            progressRepository: nil,
            practiceHistoryRepository: nil,
            referenceMaterialResolver: referenceMaterialResolver,
            clock: clock,
            localContextProvider: localContextProvider,
            persistenceStatus: .unavailable
        )
    }
}

nonisolated enum AppPersistenceStatus: Equatable {
    case available
    case unavailable
}
