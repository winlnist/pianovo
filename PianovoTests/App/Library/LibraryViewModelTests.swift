import Foundation
import Testing
@testable import Pianovo

@MainActor
struct LibraryViewModelTests {
    @Test func emptyLibraryLoadsWithoutWritingAndUnavailableDoesNotPretendEmptySuccess() async {
        let repository = LibraryRepositoryDouble()
        let model = LibraryViewModel(repository: repository)
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        #expect(model.loadState == .ready && model.exercises.isEmpty)
        #expect(repository.readCount == 1 && repository.requests.isEmpty)
        let unavailable = LibraryViewModel(repository: nil)
        await unavailable.load()
        #expect(unavailable.loadState == .unavailable && !unavailable.allowsActions)
        let editor = LibraryEditorViewModel(repository: nil)
        editor.draft = LibraryFixtures.draft
        #expect(await editor.save() == nil)
        #expect(editor.saveState == .failed(.unavailable))
    }

    @Test func invalidEditorCanBeCorrectedAndStoresNormalisedContent() async throws {
        let repository = LibraryRepositoryDouble()
        let editor = LibraryEditorViewModel(repository: repository)
        #expect(await editor.save() == nil)
        #expect(editor.saveState == .failed(.invalid([.titleRequired, .instructionsRequired, .purposeRequired])))
        #expect(editor.canEdit && repository.requests.isEmpty)
        editor.draft = LibraryFixtures.draft
        editor.draft.title = "  Scale warm-up \n"
        let created = try #require(await editor.save())
        #expect(created.currentRevision.content.title == "Scale warm-up")
        #expect(editor.saveState == .saved)
        #expect(await editor.save() == nil)
        #expect(repository.requests.count == 1)
    }

    @Test func failedCreateFreezesIdentityTimestampAndContentForRetry() async throws {
        let repository = LibraryRepositoryDouble()
        let time = AssignmentTestTime()
        var identities = 0
        let editor = LibraryEditorViewModel(repository: repository, clock: time, makeUUID: { identities += 1; return UUID() })
        editor.draft = LibraryFixtures.draft
        repository.failBeforeWrite = true
        #expect(await editor.save() == nil)
        #expect(editor.saveState == .failed(.storage) && !editor.canEdit)
        let original = try #require(repository.requests.first)
        editor.draft.title = "Not part of the attempted save"
        time.advance(100)
        repository.failBeforeWrite = false
        let result = try #require(await editor.save())
        #expect(identities == 2)
        #expect(repository.requests == [original, original])
        #expect(result.currentRevision.content.title == LibraryFixtures.draft.title)
        #expect(result.currentRevision.createdAt != time.now)
    }

    @Test func ambiguousCreateAndEditRetryWithoutDuplicatingContent() async throws {
        let repository = LibraryRepositoryDouble()
        let firstEditor = LibraryEditorViewModel(repository: repository)
        firstEditor.draft = LibraryFixtures.draft
        repository.failAfterWrite = true
        #expect(await firstEditor.save() == nil)
        repository.failAfterWrite = false
        let created = try #require(await firstEditor.save())
        #expect(try await repository.exercises().count == 1)
        let edit = LibraryEditorViewModel(exercise: created, repository: repository)
        edit.draft.title = "Adapted warm-up"
        repository.failAfterWrite = true
        #expect(await edit.save() == nil)
        repository.failAfterWrite = false
        let updated = try #require(await edit.save())
        #expect(updated.id == created.id)
        #expect(try await repository.revisionHistory(for: created.id).count == 2)
    }

    @Test func overlappingEditorSavesOnlySubmitOneFrozenMutation() async throws {
        let repository = LibraryRepositoryDouble()
        let editor = LibraryEditorViewModel(repository: repository)
        editor.draft = LibraryFixtures.draft
        repository.pauseNextWrite = true
        let first = Task { await editor.save() }
        await repository.waitUntilPaused()
        #expect(editor.saveState == .saving)
        #expect(await editor.save() == nil)
        #expect(repository.requests.count == 1)
        repository.release()
        #expect(await first.value != nil)
        #expect(editor.saveState == .saved)
    }

    @Test func staleEditorCannotOverwriteCurrentRevisionAndRetainsReferenceOrigin() async throws {
        let repository = LibraryRepositoryDouble()
        var content = LibraryFixtures.draft
        content.referenceMaterialID = PianovoReferenceMaterialCatalogue.beyerNo63ID
        let first = LibraryExerciseRevision(id: LibraryRevisionID(rawValue: UUID()), exerciseID: LibraryExerciseID(rawValue: UUID()),
            parentRevisionID: nil, content: content, createdAt: Date(), origin: LibraryFixtures.origin)
        let original = try await repository.apply(.create(first))
        let stale = LibraryEditorViewModel(exercise: original, repository: repository)
        stale.draft.title = "Stale edit"
        let current = LibraryEditorViewModel(exercise: original, repository: repository)
        current.draft.title = "Current edit"
        let updated = try #require(await current.save())
        #expect(updated.currentRevision.content.referenceMaterialID == content.referenceMaterialID)
        #expect(updated.currentRevision.origin == first.origin)
        #expect(await stale.save() == nil)
        #expect(stale.saveState == .failed(.conflict))
        #expect(try await repository.exercises() == [updated])
    }

    @Test func failedReadKeepsKnownExercisesAndRefreshesWithoutWrites() async throws {
        let repository = LibraryRepositoryDouble()
        let original = try await repository.apply(.create(LibraryFixtures.revision()))
        let model = LibraryViewModel(repository: repository)
        await model.load()
        repository.failRead = true
        await model.load()
        #expect(model.loadState == .failed && model.exercises == [original] && !model.allowsActions)
        repository.failRead = false
        await model.load()
        #expect(model.loadState == .ready && model.allowsActions)
        #expect(repository.requests.count == 1)
    }

    @Test func failedArchiveAndRefreshReflectDurableStateInsteadOfOptimisticChange() async throws {
        let repository = LibraryRepositoryDouble()
        let exercise = try await repository.apply(.create(LibraryFixtures.revision()))
        let model = LibraryViewModel(repository: repository)
        await model.load()
        repository.failBeforeWrite = true
        await model.setArchived(exercise, archived: true)
        #expect(model.archiveState == .failed(.storage))
        #expect(model.exercises == [exercise])
        #expect(!model.allowsActions)
        repository.failBeforeWrite = false
        await model.retryArchive()
        #expect(model.archiveState == .ready)
        #expect(model.exercises.first?.isArchived == true)
        await model.setArchived(try #require(model.exercises.first), archived: false)
        #expect(model.exercises == [exercise])
        repository.failAfterWrite = true
        await model.setArchived(exercise, archived: true)
        #expect(model.exercises == [exercise])
        await model.load()
        #expect(model.archiveState == .ready && model.exercises.first?.isArchived == true)
        let count = repository.requests.count
        await model.retryArchive()
        #expect(repository.requests.count == count)
    }

    @Test func archiveAndLoadAreGatedWhileWriteIsSuspended() async throws {
        let repository = LibraryRepositoryDouble()
        let exercise = try await repository.apply(.create(LibraryFixtures.revision()))
        let model = LibraryViewModel(repository: repository)
        await model.load()
        let reads = repository.readCount
        repository.pauseNextWrite = true
        let first = Task { await model.setArchived(exercise, archived: true) }
        await repository.waitUntilPaused()
        await model.setArchived(exercise, archived: false)
        await model.load()
        #expect(repository.requests.count == 2)
        #expect(repository.readCount == reads)
        repository.release()
        await first.value
        #expect(model.exercises.first?.isArchived == true)
    }

    @Test func activeArchivedSearchAndTitleOrderUseLatestContent() async throws {
        let repository = LibraryRepositoryDouble()
        let zebra = try await repository.apply(.create(LibraryFixtures.revision(title: "Zebra")))
        let alpha = try await repository.apply(.create(LibraryFixtures.revision(title: "Alpha")))
        let model = LibraryViewModel(repository: repository)
        await model.load()
        #expect(model.visibleExercises(archived: false, search: "").map(\.id) == [alpha.id, zebra.id])
        #expect(model.visibleExercises(archived: false, search: "  ALP ").map(\.id) == [alpha.id])
        await model.setArchived(alpha, archived: true)
        #expect(model.visibleExercises(archived: false, search: "").map(\.id) == [zebra.id])
        #expect(model.visibleExercises(archived: true, search: "alpha").map(\.id) == [alpha.id])
    }
}

@MainActor
private final class LibraryRepositoryDouble: LibraryExerciseRepository {
    let backing = InMemoryLibraryExerciseRepository()
    var requests: [LibraryMutation] = []
    var readCount = 0
    var failBeforeWrite = false
    var failAfterWrite = false
    var failRead = false
    var pauseNextWrite = false
    private var suspended: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?

    func exercises() async throws -> [LibraryExercise] {
        readCount += 1
        if failRead { throw LibraryTestError() }
        return try await backing.exercises()
    }
    func revisionHistory(for id: LibraryExerciseID) async throws -> [LibraryExerciseRevision] { try await backing.revisionHistory(for: id) }
    func apply(_ mutation: LibraryMutation) async throws -> LibraryExercise {
        requests.append(mutation)
        if pauseNextWrite {
            pauseNextWrite = false
            await withCheckedContinuation { continuation in
                suspended = continuation
                observer?.resume()
                observer = nil
            }
        }
        if failBeforeWrite { throw LibraryTestError() }
        let result = try await backing.apply(mutation)
        if failAfterWrite { throw LibraryTestError() }
        return result
    }
    func waitUntilPaused() async {
        if suspended != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func release() { suspended?.resume(); suspended = nil }
}
