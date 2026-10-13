import Foundation
import SwiftData
import Testing
@testable import Pianovo

@MainActor
struct ExerciseTemplateViewModelTests {
    @Test func usingTemplateTwiceCreatesIndependentExercisesWithPinnedOriginAndEditableDefaults() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        let exercises = SwiftDataLibraryExerciseRepository(container: container)
        let templates = SwiftDataLibraryTemplateRepository(container: container)
        let first = TemplateFixtures.revision(starter: .relaxedWarmUpV1)
        let template = try await templates.apply(.create(first))
        let a = LibraryEditorViewModel(template: template.currentRevision, repository: exercises)
        let b = LibraryEditorViewModel(template: template.currentRevision, repository: exercises)
        #expect(a.draft == first.content.defaults)
        a.draft.title = "Student's adapted exercise"
        let savedA = try #require(await a.save())
        let savedB = try #require(await b.save())
        #expect(savedA.id != savedB.id)
        #expect(savedA.currentRevision.id != savedB.currentRevision.id)
        #expect(savedA.currentRevision.parentRevisionID == nil)
        #expect(savedA.currentRevision.templateOrigin == LibraryTemplateOrigin(first))
        #expect(savedB.currentRevision.templateOrigin == LibraryTemplateOrigin(first))
        #expect(savedA.currentRevision.content.title != savedB.currentRevision.content.title)
        let next = TemplateFixtures.revision(templateID: first.templateID, parent: first.id, name: "Changed template", starter: first.starterPattern)
        _ = try await templates.apply(.revise(next, replacing: first.id))
        _ = try await templates.apply(.setArchived(first.templateID, expectedRevision: next.id, archived: true))
        #expect(Set(try await exercises.exercises().map(\.id)) == [savedA.id, savedB.id])
        #expect(try await exercises.revisionHistory(for: savedA.id) == [savedA.currentRevision])
        let edit = LibraryEditorViewModel(exercise: savedA, repository: exercises)
        edit.draft.instructions = "Adapted instructions"
        let edited = try #require(await edit.save())
        #expect(edited.currentRevision.templateOrigin == savedA.currentRevision.templateOrigin)
        #expect(try await templates.revisionHistory(for: first.templateID) == [first, next])
    }

    @Test func starterTemplateRequiresExplicitSaveAndRetainsStarterIdentity() async throws {
        let repository = InMemoryLibraryExerciseTemplateRepository()
        let editor = ExerciseTemplateEditorViewModel(starter: .reflectionV1, repository: repository)
        #expect(try await repository.templates().isEmpty)
        #expect(editor.draft == LibraryStarterPattern.reflectionV1.draft)
        editor.draft.name = "My reflection"
        let saved = try #require(await editor.save())
        #expect(saved.currentRevision.starterPattern == .reflectionV1)
        let edit = ExerciseTemplateEditorViewModel(template: saved, repository: repository)
        edit.draft.defaults.learningPurpose = "My next focus"
        let revised = try #require(await edit.save())
        #expect(revised.currentRevision.starterPattern == .reflectionV1)
        #expect(revised.id == saved.id && revised.ownerID == saved.ownerID)
    }

    @Test func invalidTemplateDraftCanBeCorrectedWithoutAllocatingOrWriting() async throws {
        let repository = TemplateRepositoryDouble()
        var identities = 0
        let editor = ExerciseTemplateEditorViewModel(repository: repository, makeUUID: { identities += 1; return UUID() })
        #expect(await editor.save() == nil)
        #expect(editor.canEdit && identities == 0 && repository.requests.isEmpty)
        editor.draft = TemplateFixtures.draft
        #expect(await editor.save() != nil)
        #expect(identities == 2)
    }

    @Test func failedAndAmbiguousSavesReuseFrozenIdentityContentAndTimestamp() async throws {
        let repository = TemplateRepositoryDouble()
        let clock = AssignmentTestTime()
        let editor = ExerciseTemplateEditorViewModel(repository: repository, clock: clock)
        editor.draft = TemplateFixtures.draft
        repository.failBefore = true
        #expect(await editor.save() == nil)
        let request = try #require(repository.requests.first)
        #expect(!editor.canEdit && editor.hasChanges)
        clock.advance(500)
        editor.draft.name = "Not part of attempted save"
        repository.failBefore = false
        repository.failAfter = true
        #expect(await editor.save() == nil)
        repository.failAfter = false
        let result = try #require(await editor.save())
        #expect(repository.requests == [request, request, request])
        #expect(result.currentRevision.content == TemplateFixtures.draft)
        #expect(try await repository.templates().count == 1)
        #expect(await editor.save() == nil)
    }

    @Test func concurrentSavesAreGatedAndStaleEditorDoesNotOverwrite() async throws {
        let repository = TemplateRepositoryDouble()
        let editor = ExerciseTemplateEditorViewModel(repository: repository)
        editor.draft = TemplateFixtures.draft
        repository.pauseNext = true
        let first = Task { await editor.save() }
        await repository.waitUntilPaused()
        #expect(editor.saveState == .saving)
        #expect(await editor.save() == nil)
        repository.release()
        let original = try #require(await first.value)
        let current = ExerciseTemplateEditorViewModel(template: original, repository: repository)
        let stale = ExerciseTemplateEditorViewModel(template: original, repository: repository)
        current.draft.name = "Current"
        stale.draft.name = "Stale"
        let result = try #require(await current.save())
        #expect(await stale.save() == nil)
        #expect(stale.saveState == .failed(.conflict))
        #expect(try await repository.templates() == [result])
    }

    @Test func listReadArchiveRetryAndRefreshReflectDurableState() async throws {
        let repository = TemplateRepositoryDouble()
        let original = try await repository.apply(.create(TemplateFixtures.revision()))
        let model = ExerciseTemplateViewModel(repository: repository)
        await model.loadIfNeeded()
        #expect(model.visibleTemplates(archived: false, search: " warm ") == [original])
        repository.failRead = true
        await model.load()
        #expect(model.loadState == .failed && model.templates == [original] && !model.allowsActions)
        repository.failRead = false
        await model.load()
        repository.failBefore = true
        await model.setArchived(original, archived: true)
        #expect(model.actionState == .failed(.storage) && model.templates == [original])
        repository.failBefore = false
        await model.retryArchive()
        #expect(model.visibleTemplates(archived: false, search: "").isEmpty)
        #expect(model.visibleTemplates(archived: true, search: "").count == 1)
        let archived = try #require(model.templates.first)
        repository.failAfter = true
        await model.setArchived(archived, archived: false)
        #expect(model.templates == [archived])
        await model.load()
        #expect(model.templates == [original] && model.actionState == .ready)
    }

    @Test func unavailableTemplateStoreDoesNotUseAnInMemoryFallback() async {
        let model = ExerciseTemplateViewModel(repository: nil)
        await model.load()
        #expect(model.loadState == .unavailable && !model.allowsActions)
        let editor = ExerciseTemplateEditorViewModel(starter: .relaxedWarmUpV1, repository: nil)
        #expect(await editor.save() == nil)
        #expect(editor.saveState == .failed(.unavailable))
    }
}

@MainActor
private final class TemplateRepositoryDouble: LibraryExerciseTemplateRepository {
    let backing = InMemoryLibraryExerciseTemplateRepository()
    var requests: [LibraryTemplateMutation] = []
    var failBefore = false
    var failAfter = false
    var failRead = false
    var pauseNext = false
    private var suspended: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    func templates() async throws -> [LibraryExerciseTemplate] {
        if failRead { throw LibraryTestError() }
        return try await backing.templates()
    }
    func revisionHistory(for id: LibraryTemplateID) async throws -> [LibraryExerciseTemplateRevision] { try await backing.revisionHistory(for: id) }
    func apply(_ mutation: LibraryTemplateMutation) async throws -> LibraryExerciseTemplate {
        requests.append(mutation)
        if pauseNext {
            pauseNext = false
            await withCheckedContinuation { continuation in
                suspended = continuation
                observer?.resume()
                observer = nil
            }
        }
        if failBefore { throw LibraryTestError() }
        let result = try await backing.apply(mutation)
        if failAfter { throw LibraryTestError() }
        return result
    }
    func waitUntilPaused() async {
        if suspended != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func release() { suspended?.resume(); suspended = nil }
}
