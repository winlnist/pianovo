import Foundation
import SwiftData
import Testing
@testable import Pianovo

@MainActor
struct LearnerProgrammeTests {
    @Test(arguments: [false, true])
    func instantiationSwitchingAndPinnedContentAreIndependent(swiftData: Bool) async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: swiftData)
        let firstRequest = LearnerFixtures.creation(fixture.template, selection: .initial)
        let first = try await fixture.plans.apply(firstRequest)
        let firstPlan = try #require(first.selectedPlan)
        let second = try await fixture.plans.apply(LearnerFixtures.creation(fixture.template, selection: first.selection))
        let secondPlan = try #require(second.selectedPlan)
        #expect(firstPlan.id != secondPlan.id)
        #expect(firstPlan.currentDayID != secondPlan.currentDayID)
        let a = try #require(firstPlan.currentDay?.sections.first?.placements.first)
        let b = try #require(secondPlan.currentDay?.sections.first?.placements.first)
        #expect(a.id != b.id && a.exercise == b.exercise)
        #expect(a.id != fixture.template.content.weeks[0].days[0].sections[0].placements[0].id)
        #expect(firstPlan.completions.isEmpty && secondPlan.completions.isEmpty)
        #expect(firstPlan.revision.origin.revisionID == fixture.template.id)
        let originalExercise = fixture.exercise.currentRevision
        let edited = LibraryFixtures.revision(exerciseID: fixture.exercise.id, parent: originalExercise.id, title: "Updated exercise")
        _ = try await fixture.exercises.apply(.revise(edited, replacing: originalExercise.id))
        _ = try await fixture.exercises.apply(.setArchived(fixture.exercise.id, expectedRevision: edited.id, archived: true))
        let original = try await fixture.plans.apply(LearnerProgrammeRequest(id: UUID(), expectedSelection: second.selection.version, command: .select(nil)))
        #expect(original.selection.planID == nil)
        let restored = try await fixture.plans.apply(LearnerProgrammeRequest(id: UUID(), expectedSelection: original.selection.version, command: .select(firstPlan.id)))
        #expect(restored.selectedPlan?.revision.exercise(a.exercise) == originalExercise)
        #expect(restored.selectedPlan?.currentDayID == firstPlan.currentDayID)
        // Replaying an earlier create must not reselect it or duplicate content.
        #expect(try await fixture.plans.apply(firstRequest) == restored)
    }

    @Test func unfinishedWarningWeekBoundaryRecoveryFinalDayAndUndo() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: true)
        var state = try await fixture.plans.apply(LearnerFixtures.creation(fixture.template, selection: .initial))
        var plan = try #require(state.selectedPlan)
        let placement = try #require(plan.currentDay?.sections.first?.placements.first)
        await #expect(throws: LearnerProgrammeError.unfinishedWork) {
            try await fixture.plans.apply(LearnerFixtures.move(plan, state.selection, direction: 1, confirmed: false))
        }
        state = try await fixture.plans.apply(LearnerFixtures.completion(plan, state.selection, assignment: placement.id, completed: true))
        plan = try #require(state.selectedPlan)
        #expect(plan.isCompleted(placement.id) && plan.unfinishedCount == 0)
        state = try await fixture.plans.apply(LearnerFixtures.completion(plan, state.selection, assignment: placement.id, completed: false))
        plan = try #require(state.selectedPlan)
        #expect(!plan.isCompleted(placement.id) && plan.completions.count == 2)
        state = try await fixture.plans.apply(LearnerFixtures.move(plan, state.selection, direction: 1, confirmed: true))
        plan = try #require(state.selectedPlan)
        #expect(plan.currentDay?.isRecovery == true)
        #expect(!plan.isCompleted(placement.id))
        state = try await fixture.plans.apply(LearnerFixtures.move(plan, state.selection, direction: 1))
        plan = try #require(state.selectedPlan)
        #expect(plan.currentDayID == plan.revision.content.weeks[1].days[0].id)
        let finalDay = plan.currentDayID
        state = try await fixture.plans.apply(LearnerFixtures.move(plan, state.selection, direction: 1))
        plan = try #require(state.selectedPlan)
        #expect(plan.reachedEnd && plan.currentDayID == finalDay)
        await #expect(throws: LearnerProgrammeError.invalidPosition) {
            try await fixture.plans.apply(LearnerFixtures.move(plan, state.selection, direction: 1))
        }
        state = try await fixture.plans.apply(LearnerFixtures.move(plan, state.selection, direction: -1))
        #expect(state.selectedPlan?.currentDay?.isRecovery == true && state.selectedPlan?.reachedEnd == false)
        #expect(state.selectedPlan?.completions.count == 2)
    }

    @Test func editingRetainsUnchangedStatusAndReplacesChangedWorkWithNewOccurrence() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: true)
        var state = try await fixture.plans.apply(LearnerFixtures.creation(fixture.template, selection: .initial))
        var plan = try #require(state.selectedPlan)
        let assignment = try #require(plan.currentDay?.sections.first?.placements.first)
        state = try await fixture.plans.apply(LearnerFixtures.completion(plan, state.selection, assignment: assignment.id, completed: true))
        plan = try #require(state.selectedPlan)
        var content = plan.revision.content
        content.name = "Personalised name"
        state = try await fixture.plans.apply(LearnerFixtures.edit(plan, content: content))
        plan = try #require(state.selectedPlan)
        #expect(plan.isCompleted(assignment.id))
        let priorRevision = plan.revision
        content.weeks[0].days[0].sections[0].placements[0].goal = "New work goal"
        state = try await fixture.plans.apply(LearnerFixtures.edit(plan, content: content))
        plan = try #require(state.selectedPlan)
        let replacement = try #require(plan.currentDay?.sections.first?.placements.first)
        #expect(replacement.id != assignment.id && !plan.isCompleted(replacement.id))
        #expect(plan.completions.first?.assignmentID == assignment.id)
        #expect(plan.revision.origin == priorRevision.origin)
        #expect(try await fixture.plans.revisions(for: plan.id).count == 3)
        #expect(try await fixture.templates.revisionHistory(for: fixture.template.templateID) == [fixture.template])
        content = plan.revision.content
        content.weeks[0].days.removeFirst()
        await #expect(throws: LearnerProgrammeError.currentDayRemoved) { try await fixture.plans.apply(LearnerFixtures.edit(plan, content: content)) }
        #expect(try await fixture.plans.snapshot() == state)
    }

    @Test func staleSelectionAndPositionCannotChangeAnotherProgramme() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: true)
        let state = try await fixture.plans.apply(LearnerFixtures.creation(fixture.template, selection: .initial))
        let plan = try #require(state.selectedPlan)
        await #expect(throws: LearnerProgrammeError.conflict) {
            try await fixture.plans.apply(LearnerProgrammeRequest(id: UUID(), expectedSelection: nil, command: .select(nil)))
        }
        let pendingAdvance = LearnerFixtures.move(plan, state.selection, direction: 1, confirmed: true)
        let original = try await fixture.plans.apply(LearnerProgrammeRequest(id: UUID(), expectedSelection: state.selection.version, command: .select(nil)))
        await #expect(throws: LearnerProgrammeError.conflict) { try await fixture.plans.apply(pendingAdvance) }
        #expect(try await fixture.plans.snapshot() == original)
        let back = try await fixture.plans.apply(LearnerProgrammeRequest(id: UUID(), expectedSelection: original.selection.version, command: .select(plan.id)))
        await #expect(throws: LearnerProgrammeError.conflict) { try await fixture.plans.apply(pendingAdvance) }
        let next = try await fixture.plans.apply(LearnerFixtures.move(try #require(back.selectedPlan), back.selection, direction: 1, confirmed: true))
        let outdated = LearnerFixtures.move(plan, next.selection, direction: 1, confirmed: true)
        await #expect(throws: LearnerProgrammeError.conflict) { try await fixture.plans.apply(outdated) }
    }

    @Test func failuresRollbackAndRetryReceiptsPreventDuplicateOrRegressiveWrites() async throws {
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        let fixture = try await LearnerFixtures.seed(container)
        var before = true
        var after = false
        let repository = SwiftDataLearnerProgrammeRepository(container: container, save: { context in
            if before { throw LibraryTestError() }; try context.save(); if after { throw LibraryTestError() }
        })
        let request = LearnerFixtures.creation(fixture.template, selection: .initial)
        await #expect(throws: LibraryTestError.self) { try await repository.apply(request) }
        #expect(try await repository.snapshot() == LearnerProgrammeSnapshot())
        #expect(try ModelContext(container).fetch(FetchDescriptor<LibrarySchemaV4.LearnerRevisionModel>()).isEmpty)
        #expect(try ModelContext(container).fetch(FetchDescriptor<LibrarySchemaV4.ReceiptModel>()).isEmpty)
        before = false; after = true
        await #expect(throws: LibraryTestError.self) { try await repository.apply(request) }
        let saved = try await repository.apply(request)
        #expect(saved.plans.count == 1)
        before = true; after = false
        let plan = try #require(saved.selectedPlan)
        await #expect(throws: LibraryTestError.self) { try await repository.apply(LearnerFixtures.move(plan, saved.selection, direction: 1, confirmed: true)) }
        #expect(try await repository.snapshot() == saved)
        let noOp = SwiftDataLearnerProgrammeRepository(container: container, save: { _ in })
        await #expect(throws: LearnerProgrammeError.verificationFailed) {
            try await noOp.apply(LearnerProgrammeRequest(id: UUID(), expectedSelection: saved.selection.version, command: .select(nil)))
        }
        #expect(try await repository.snapshot() == saved)
        let reused = LearnerProgrammeRequest(id: request.id, expectedSelection: nil, command: .select(nil))
        await #expect(throws: LearnerProgrammeError.conflict) { try await repository.apply(reused) }
    }

    @Test func missingReferencesInvalidPositionAndCorruptSelectionNeverReset() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: true)
        var bad = LearnerFixtures.creation(fixture.template, selection: .initial)
        let falseOrigin = LibraryProgrammeOrigin(templateID: fixture.template.templateID, revisionID: LibraryProgrammeRevisionID(rawValue: UUID()), name: fixture.template.content.name, creatorAttribution: nil)
        bad = LearnerProgrammeRequest(id: bad.id, expectedSelection: .some(TodayProgrammeSelection.initial.version), command:
            .create(LearnerPlanID(rawValue: UUID()), LearnerPlanRevisionID(rawValue: UUID()), fixture.template.content.independentCopy(), falseOrigin, LearnerFixtures.timestamp))
        await #expect(throws: LearnerProgrammeError.missingReference) { try await fixture.plans.apply(bad) }
        #expect(try await fixture.plans.snapshot().plans.isEmpty)
        await #expect(throws: LearnerProgrammeError.invalidPosition) {
            try await fixture.plans.apply(LearnerProgrammeRequest(id: UUID(), expectedSelection: TodayProgrammeSelection.initial.version, command: .select(LearnerPlanID(rawValue: UUID()))))
        }
        let container = try LibraryModelContainerFactory.makeContainer(inMemory: true)
        let writer = ModelContext(container)
        writer.insert(try LibrarySchemaV4.SelectionModel(TodayProgrammeSelection(version: UUID(), planID: LearnerPlanID(rawValue: UUID()))))
        try writer.save()
        await #expect(throws: LearnerProgrammeError.corruptStore) { try await SwiftDataLearnerProgrammeRepository(container: container).snapshot() }
    }

    @Test func sharedTemplateIdentitiesAreRejectedAndEditingAnEndedPlanKeepsItsSavedDay() async throws {
        let fixture = try await LearnerFixtures.repositories(swiftData: true)
        let source = fixture.template
        let origin = LibraryProgrammeOrigin(templateID: source.templateID, revisionID: source.id, name: source.content.name, creatorAttribution: nil)
        let invalid = LearnerProgrammeRequest(id: UUID(), expectedSelection: TodayProgrammeSelection.initial.version,
            command: .create(LearnerPlanID(rawValue: UUID()), LearnerPlanRevisionID(rawValue: UUID()), source.content, origin, LearnerFixtures.timestamp))
        await #expect(throws: LearnerProgrammeError.unsupportedChange) { try await fixture.plans.apply(invalid) }
        var state = try await fixture.plans.apply(LearnerFixtures.creation(source, selection: .initial))
        for _ in 0..<3 {
            state = try await fixture.plans.apply(LearnerFixtures.move(try #require(state.selectedPlan), state.selection, direction: 1, confirmed: true))
        }
        let ended = try #require(state.selectedPlan)
        #expect(ended.reachedEnd)
        var content = ended.revision.content
        content.name = "Reviewed personal plan"
        state = try await fixture.plans.apply(LearnerFixtures.edit(ended, content: content))
        #expect(state.selectedPlan?.reachedEnd == false)
        #expect(state.selectedPlan?.currentDayID == ended.currentDayID)
        #expect(state.selectedPlan?.completions == ended.completions)
    }

    @Test func realV3MigrationAndLegacyProgressCoexistenceSurviveReopening() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Library.store")
        let progressURL = folder.appendingPathComponent("Progress.store")
        let exerciseRevision = LibraryFixtures.revision()
        let owner = LibraryOwnerID(rawValue: UUID())
        let exercise = LibraryExercise(id: exerciseRevision.exerciseID, ownerID: owner, currentRevision: exerciseRevision, isArchived: true)
        let reference = LibraryExerciseReference(exerciseID: exercise.id, revisionID: exerciseRevision.id)
        let template = ProgrammeFixtures.revision(content: ProgrammeFixtures.draft(reference: reference))
        let header = LibraryProgrammeTemplate(id: template.templateID, ownerID: owner, currentRevision: template, isArchived: false)
        let exerciseTemplate = TemplateFixtures.revision()
        try autoreleasepool {
            let schema = Schema(versionedSchema: LibrarySchemaV3.self)
            let container = try ModelContainer(for: schema, migrationPlan: LegacyLearnerV3MigrationPlan.self,
                configurations: [ModelConfiguration("PianovoLibrary", schema: schema, url: url, cloudKitDatabase: .none)])
            let writer = ModelContext(container); writer.autosaveEnabled = false
            writer.insert(LibrarySchemaV1.IdentityModel(ownerID: owner)); writer.insert(LibrarySchemaV1.ExerciseModel(exercise))
            writer.insert(try LibrarySchemaV1.RevisionModel(exerciseRevision))
            writer.insert(LibrarySchemaV2.TemplateModel(LibraryExerciseTemplate(id: exerciseTemplate.templateID, ownerID: owner, currentRevision: exerciseTemplate, isArchived: true)))
            writer.insert(try LibrarySchemaV2.TemplateRevisionModel(exerciseTemplate))
            writer.insert(LibrarySchemaV3.ProgrammeModel(header)); writer.insert(try LibrarySchemaV3.ProgrammeRevisionModel(template))
            try writer.save()
        }
        let progressSchema = Schema(PracticeHistorySchemaV1.models)
        let originalContainer = try ModelContainer(for: progressSchema, migrationPlan: PracticeHistoryMigrationPlan.self,
            configurations: [ModelConfiguration(schema: progressSchema, url: progressURL, cloudKitDatabase: .none)])
        let legacy = SwiftDataPracticeHistoryRepository(context: ModelContext(originalContainer))
        try await legacy.saveActiveProgress(try Fixtures.activeProgress())
        try await legacy.updateAssignmentCompletion(try Fixtures.completion())
        try await legacy.recordSession(try Fixtures.session())
        let oldProgress = try #require(try await legacy.loadProgress(programmeID: try Fixtures.programme().programmeID))
        let oldHistory = try await legacy.chronologicalHistory()
        let upgraded = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        #expect(try await SwiftDataLibraryExerciseRepository(container: upgraded).exercises() == [exercise])
        #expect(try await SwiftDataLibraryProgrammeRepository(container: upgraded).templates() == [header])
        let retainedExerciseTemplates = try await SwiftDataLibraryTemplateRepository(container: upgraded).templates()
        #expect(retainedExerciseTemplates.count == 1 && retainedExerciseTemplates[0].isArchived)
        #expect(retainedExerciseTemplates[0].currentRevision == exerciseTemplate)
        let repository = SwiftDataLearnerProgrammeRepository(container: upgraded)
        #expect(try await repository.snapshot().selection == .initial)
        let state = try await repository.apply(LearnerFixtures.creation(template, selection: .initial))
        #expect(state.selectedPlan?.ownerID == owner)
        let switched = try await repository.apply(LearnerProgrammeRequest(id: UUID(), expectedSelection: state.selection.version, command: .select(nil)))
        let reopened = try LibraryModelContainerFactory.makeContainer(storeURL: url)
        #expect(try await SwiftDataLearnerProgrammeRepository(container: reopened).snapshot() == switched)
        let reopenedProgress = try ModelContainer(for: progressSchema, migrationPlan: PracticeHistoryMigrationPlan.self,
            configurations: [ModelConfiguration(schema: progressSchema, url: progressURL, cloudKitDatabase: .none)])
        let history = SwiftDataPracticeHistoryRepository(context: ModelContext(reopenedProgress))
        #expect(try await history.loadProgress(programmeID: try Fixtures.programme().programmeID) == oldProgress)
        #expect(try await history.chronologicalHistory() == oldHistory)
        #expect(PracticeHistoryMigrationPlan.schemas.count == 1 && PracticeHistorySchemaV1.models.count == 6)
    }
}

@MainActor
enum LearnerFixtures {
    static var timestamp: PracticeTimestamp { PracticeTimestamp(instant: Date(timeIntervalSince1970: 100), timeZone: TimeZone(identifier: "Europe/London")!) }
    struct Repositories {
        let exercises: any LibraryExerciseRepository
        let templates: any LibraryProgrammeTemplateRepository
        let plans: any LearnerProgrammeRepository
        let exercise: LibraryExercise
        let template: LibraryProgrammeTemplateRevision
    }
    static func repositories(swiftData: Bool) async throws -> Repositories {
        if swiftData { return try await seed(LibraryModelContainerFactory.makeContainer(inMemory: true)) }
        let exercises = InMemoryLibraryExerciseRepository()
        let templates = InMemoryLibraryProgrammeTemplateRepository(exerciseRepository: exercises)
        let plans = InMemoryLearnerProgrammeRepository(exercises: exercises, templates: templates)
        return try await seed(exercises: exercises, templates: templates, plans: plans)
    }
    static func seed(_ container: ModelContainer) async throws -> Repositories {
        try await seed(exercises: SwiftDataLibraryExerciseRepository(container: container), templates: SwiftDataLibraryProgrammeRepository(container: container),
            plans: SwiftDataLearnerProgrammeRepository(container: container))
    }
    private static func seed(exercises: any LibraryExerciseRepository, templates: any LibraryProgrammeTemplateRepository, plans: any LearnerProgrammeRepository) async throws -> Repositories {
        let exercise = try await exercises.apply(.create(LibraryFixtures.revision()))
        let reference = LibraryExerciseReference(exerciseID: exercise.id, revisionID: exercise.currentRevision.id)
        var content = ProgrammeFixtures.draft(reference: reference)
        content.weeks[0].days.append(LibraryProgrammeDay(id: UUID(), isRecovery: true))
        content.weeks.append(LibraryProgrammeWeek(id: UUID(), days: [LibraryProgrammeDay(id: UUID())]))
        let revision = ProgrammeFixtures.revision(content: content)
        _ = try await templates.apply(.create(revision))
        return Repositories(exercises: exercises, templates: templates, plans: plans, exercise: exercise, template: revision)
    }
    static func creation(_ template: LibraryProgrammeTemplateRevision, selection: TodayProgrammeSelection) -> LearnerProgrammeRequest {
        LearnerProgrammeRequest(id: UUID(), expectedSelection: selection.version, command:
            .create(LearnerPlanID(rawValue: UUID()), LearnerPlanRevisionID(rawValue: UUID()), template.content.independentCopy(),
                LibraryProgrammeOrigin(templateID: template.templateID, revisionID: template.id, name: template.content.name, creatorAttribution: nil), timestamp))
    }
    static func completion(_ plan: LearnerPlan, _ selection: TodayProgrammeSelection, assignment: UUID, completed: Bool) -> LearnerProgrammeRequest {
        LearnerProgrammeRequest(id: UUID(), expectedSelection: selection.version, command: .complete(plan.id, plan.version, plan.currentDayID, assignment, completed, timestamp))
    }
    static func move(_ plan: LearnerPlan, _ selection: TodayProgrammeSelection, direction: Int, confirmed: Bool = false) -> LearnerProgrammeRequest {
        LearnerProgrammeRequest(id: UUID(), expectedSelection: selection.version, command: .move(plan.id, plan.version, plan.currentDayID, direction, confirmed))
    }
    static func edit(_ plan: LearnerPlan, content: LibraryProgrammeDraft) -> LearnerProgrammeRequest {
        let replacements = Dictionary(uniqueKeysWithValues: plan.revision.content.weeks.flatMap(\.days).flatMap(\.sections).flatMap(\.placements).map { ($0.id, UUID()) })
        return LearnerProgrammeRequest(id: UUID(), expectedSelection: nil, command: .edit(plan.id, plan.version, LearnerPlanRevisionID(rawValue: UUID()), content, replacements, timestamp))
    }
}
private enum LegacyLearnerV3MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self, LibrarySchemaV2.self, LibrarySchemaV3.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: LibrarySchemaV1.self, toVersion: LibrarySchemaV2.self), .lightweight(fromVersion: LibrarySchemaV2.self, toVersion: LibrarySchemaV3.self)] }
}
