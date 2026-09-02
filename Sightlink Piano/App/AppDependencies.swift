import Foundation
import SwiftData

@MainActor
struct AppDependencies {
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
        retainedModelContainer: ModelContainer? = nil
    ) {
        self.progressRepository = progressRepository
        self.practiceHistoryRepository = practiceHistoryRepository
        self.referenceMaterialResolver = referenceMaterialResolver
        self.clock = clock
        self.localContextProvider = localContextProvider
        self.persistenceStatus = persistenceStatus
        self.retainedModelContainer = retainedModelContainer
    }

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
        AppDependencies(
            progressRepository: repository,
            practiceHistoryRepository: repository,
            referenceMaterialResolver: referenceMaterialResolver,
            clock: clock,
            localContextProvider: localContextProvider,
            persistenceStatus: .available
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
