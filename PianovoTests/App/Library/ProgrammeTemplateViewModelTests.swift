import Foundation
import Testing
@testable import Pianovo

@MainActor
struct ProgrammeTemplateViewModelTests {
    @Test func placementsRepeatIndependentlyAndCopyPinsOriginWithoutChangingSource() async throws {
        let exercises = InMemoryLibraryExerciseRepository()
        let programmes = InMemoryLibraryProgrammeTemplateRepository(exerciseRepository: exercises)
        let exercise = try await exercises.apply(.create(LibraryFixtures.revision()))
        let clock = AssignmentTestTime()
        let editor = ProgrammeTemplateEditorViewModel(repository: programmes, clock: clock)
        editor.draft.name = "A beginner plan"
        let week = editor.draft.weeks[0].id
        let day = editor.draft.weeks[0].days[0].id
        editor.addSection(weekID: week, dayID: day)
        let section = editor.draft.weeks[0].days[0].sections[0].id
        editor.addExercise(exercise, weekID: week, dayID: day, sectionID: section)
        editor.addExercise(exercise, weekID: week, dayID: day, sectionID: section)
        let placements = editor.draft.weeks[0].days[0].sections[0].placements
        #expect(placements.count == 2 && placements[0].id != placements[1].id)
        #expect(placements[0].exercise == placements[1].exercise)
        #expect(placements[0].goal == exercise.currentRevision.content.learningPurpose)
        let original = try #require(await editor.save())
        let copyEditor = ProgrammeTemplateEditorViewModel(copying: original.currentRevision, repository: programmes, clock: clock)
        copyEditor.draft.name = "Adapted plan"
        copyEditor.draft.weeks[0].days[0].sections[0].placements[0].minutes = 15
        let copied = try #require(await copyEditor.save())
        #expect(copied.id != original.id && copied.currentRevision.parentRevisionID == nil)
        #expect(copied.currentRevision.origin?.revisionID == original.currentRevision.id)
        #expect(copied.currentRevision.content.references == original.currentRevision.content.references)
        #expect(try await programmes.revisionHistory(for: original.id) == [original.currentRevision])
        let edit = ProgrammeTemplateEditorViewModel(template: copied, repository: programmes, clock: clock)
        edit.draft.name = "More adapted"
        let changed = try #require(await edit.save())
        #expect(changed.currentRevision.origin == copied.currentRevision.origin)
    }

    @Test func invalidDraftWritesNothingAndStructuralChangesRemainBounded() async throws {
        let repository = ProgrammeRepositoryDouble()
        var allocated = 0
        let editor = ProgrammeTemplateEditorViewModel(repository: repository, clock: AssignmentTestTime(), makeUUID: { allocated += 1; return UUID() })
        let initial = allocated
        #expect(await editor.save() == nil)
        #expect(editor.canEdit && repository.requests.isEmpty && allocated == initial)
        editor.draft.name = "Valid template"
        let w = editor.draft.weeks[0].id
        for _ in 0..<9 { editor.addDay(weekID: w) }
        #expect(editor.draft.weeks[0].days.count == 7)
        let d = editor.draft.weeks[0].days[0].id
        for _ in 0..<10 { editor.addSection(weekID: w, dayID: d) }
        #expect(editor.draft.weeks[0].days[0].sections.count == 8)
        #expect(await editor.save() != nil)
    }

    @Test func failedAndAmbiguousSavesKeepOriginalIdentityContentAndTime() async throws {
        let repository = ProgrammeRepositoryDouble()
        let clock = AssignmentTestTime()
        let editor = ProgrammeTemplateEditorViewModel(repository: repository, clock: clock)
        editor.draft.name = "Original request"
        repository.failBefore = true
        #expect(await editor.save() == nil)
        let request = try #require(repository.requests.first)
        #expect(!editor.canEdit && editor.hasChanges)
        clock.advance(500)
        editor.draft.name = "Not in the frozen request"
        editor.addWeek()
        #expect(editor.draft.weeks.count == 1)
        repository.failBefore = false; repository.failAfter = true
        #expect(await editor.save() == nil)
        repository.failAfter = false
        let result = try #require(await editor.save())
        #expect(repository.requests == [request, request, request])
        #expect(result.currentRevision.content.name == "Original request")
        #expect(try await repository.templates().count == 1)
        #expect(await editor.save() == nil)
    }

    @Test func concurrentSaveAndStaleEditorDoNotOverwrite() async throws {
        let repository = ProgrammeRepositoryDouble()
        let clock = AssignmentTestTime()
        let editor = ProgrammeTemplateEditorViewModel(repository: repository, clock: clock)
        editor.draft.name = "Original"
        repository.pauseNext = true
        let saving = Task { await editor.save() }
        await repository.waitUntilPaused()
        #expect(editor.saveState == .saving)
        #expect(await editor.save() == nil)
        repository.release()
        let original = try #require(await saving.value)
        let a = ProgrammeTemplateEditorViewModel(template: original, repository: repository, clock: clock)
        let b = ProgrammeTemplateEditorViewModel(template: original, repository: repository, clock: clock)
        a.draft.name = "Updated"; b.draft.name = "Stale"
        let current = try #require(await a.save())
        #expect(await b.save() == nil && b.saveState == .failed(.conflict))
        #expect(try await repository.templates() == [current])
    }

    @Test func listReadFailuresArchiveRetryAndRefreshPreserveKnownContent() async throws {
        let repository = ProgrammeRepositoryDouble()
        let saved = try await repository.apply(.create(ProgrammeFixtures.revision()))
        let model = ProgrammeTemplateViewModel(repository: repository, exerciseRepository: InMemoryLibraryExerciseRepository(), clock: AssignmentTestTime())
        await model.loadIfNeeded()
        #expect(model.visibleTemplates(archived: false, search: " programme ") == [saved])
        repository.failRead = true
        await model.load()
        #expect(model.loadState == .failed && model.templates == [saved] && !model.allowsActions)
        repository.failRead = false; await model.load()
        repository.failBefore = true
        await model.setArchived(saved, archived: true)
        #expect(model.templates == [saved] && model.actionState == .failed(.storage))
        repository.failBefore = false; await model.retryArchive()
        #expect(model.visibleTemplates(archived: false, search: "").isEmpty)
        let archived = try #require(model.templates.first)
        repository.failAfter = true
        await model.setArchived(archived, archived: false)
        #expect(model.templates == [archived])
        await model.load()
        #expect(model.templates == [saved] && model.actionState == .ready)
    }

    @Test func oldArchivedExerciseRevisionStillResolvesAndMissingReferenceDisablesActions() async throws {
        let exercises = InMemoryLibraryExerciseRepository()
        let programmes = InMemoryLibraryProgrammeTemplateRepository(exerciseRepository: exercises)
        let first = LibraryFixtures.revision()
        let exercise = try await exercises.apply(.create(first))
        let reference = LibraryExerciseReference(exerciseID: exercise.id, revisionID: first.id)
        _ = try await programmes.apply(.create(ProgrammeFixtures.revision(content: ProgrammeFixtures.draft(reference: reference))))
        let next = LibraryFixtures.revision(exerciseID: exercise.id, parent: first.id, title: "Updated exercise")
        _ = try await exercises.apply(.revise(next, replacing: first.id))
        _ = try await exercises.apply(.setArchived(exercise.id, expectedRevision: next.id, archived: true))
        let model = ProgrammeTemplateViewModel(repository: programmes, exerciseRepository: exercises, clock: AssignmentTestTime())
        await model.load()
        #expect(model.loadState == .ready && model.revisions[reference] == first)
        let broken = ProgrammeTemplateViewModel(repository: programmes, exerciseRepository: InMemoryLibraryExerciseRepository(), clock: AssignmentTestTime())
        await broken.load()
        #expect(broken.loadState == .failed && !broken.allowsActions)
    }

    @Test func unavailableStoreDoesNotFallbackOrSilentlySeedStarter() async throws {
        let repository = InMemoryLibraryProgrammeTemplateRepository()
        let editor = ProgrammeTemplateEditorViewModel(starterWeeks: 12, repository: repository, clock: AssignmentTestTime())
        #expect(editor.draft.weeks.count == 12)
        #expect(try await repository.templates().isEmpty)
        let unavailable = ProgrammeTemplateViewModel(repository: nil, exerciseRepository: nil, clock: AssignmentTestTime())
        await unavailable.load()
        #expect(unavailable.loadState == .unavailable && !unavailable.allowsActions)
        let failed = ProgrammeTemplateEditorViewModel(repository: nil, clock: AssignmentTestTime())
        #expect(await failed.save() == nil && failed.saveState == .failed(.unavailable))
    }
}
@MainActor
private final class ProgrammeRepositoryDouble: LibraryProgrammeTemplateRepository {
    let backing = InMemoryLibraryProgrammeTemplateRepository()
    var requests: [LibraryProgrammeMutation] = []
    var failBefore = false
    var failAfter = false
    var failRead = false
    var pauseNext = false
    private var suspended: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    func templates() async throws -> [LibraryProgrammeTemplate] {
        if failRead { throw LibraryTestError() }; return try await backing.templates()
    }
    func revisionHistory(for id: LibraryProgrammeTemplateID) async throws -> [LibraryProgrammeTemplateRevision] { try await backing.revisionHistory(for: id) }
    func apply(_ mutation: LibraryProgrammeMutation) async throws -> LibraryProgrammeTemplate {
        requests.append(mutation)
        if pauseNext {
            pauseNext = false
            await withCheckedContinuation { continuation in suspended = continuation; observer?.resume(); observer = nil }
        }
        if failBefore { throw LibraryTestError() }
        let value = try await backing.apply(mutation)
        if failAfter { throw LibraryTestError() }
        return value
    }
    func waitUntilPaused() async { if suspended != nil { return }; await withCheckedContinuation { observer = $0 } }
    func release() { suspended?.resume(); suspended = nil }
}
