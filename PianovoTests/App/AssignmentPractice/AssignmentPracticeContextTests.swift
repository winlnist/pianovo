import Testing
@testable import Pianovo

@MainActor
struct AssignmentPracticeContextTests {
    @Test func preservesCompleteHierarchyWithoutParsingIDs() throws {
        let day = AssignmentFixtures.day()
        let block = day.morningBlocks[0]
        let launch = try #require(AssignmentPracticeContext(day: day, blockID: block.id, assignmentID: block.assignments[0].id))
        #expect(launch.recordContext == PracticeRecordContext(
            programme: ProgrammeDefinitionReference(programmeID: day.programme.programmeID, programmeVersion: 7),
            weekID: day.weekID, dayID: day.dayID, blockID: block.id,
            assignmentID: block.assignments[0].id, sourceID: block.assignments[0].sourceID))
        #expect(launch.blockCategory == .sightReading)
        #expect(launch.title == "Reading assignment")
        #expect(launch.goal == "Read steadily")
        #expect(launch.plannedDurationMinutes == 10)
    }

    @Test(arguments: ["unknown", "beyer-op101-no-63", "technique-daily-control", "repertoire-harmony-general", "review-practice-notes", "reflection-recovery-day"])
    func unsupportedSourcesFailClosed(source: String) {
        let day = AssignmentFixtures.day(source: source)
        #expect(AssignmentPracticeContext(day: day, blockID: day.morningBlocks[0].id,
                                          assignmentID: day.morningBlocks[0].assignments[0].id) == nil)
    }

    @Test func invalidHierarchyAndWrongCategoryFailClosed() {
        let day = AssignmentFixtures.day()
        #expect(AssignmentPracticeContext(day: day, blockID: PracticeBlockID("missing")!,
                                          assignmentID: day.morningBlocks[0].assignments[0].id) == nil)
        #expect(AssignmentPracticeContext(day: day, blockID: day.morningBlocks[0].id,
                                          assignmentID: PracticeAssignmentID("missing")!) == nil)
        let technique = AssignmentFixtures.day(category: .technique)
        #expect(AssignmentPracticeContext(day: technique, blockID: technique.morningBlocks[0].id,
                                          assignmentID: technique.morningBlocks[0].assignments[0].id) == nil)
    }

    @Test func seedExposesOnlyMorningGeneratedSightReadingOnPracticeDays() async throws {
        let repository = InMemoryPracticeHistoryRepository()
        for number in 1...7 {
            try await repository.saveActiveProgress(try Fixtures.activeProgress(currentDayID: "week-01-day-0\(number)"))
            let model = TodayViewModel(progressRepository: repository, practiceHistoryRepository: repository)
            await model.load()
            guard case .loaded(let day) = model.state else { Issue.record("Expected loaded day"); return }
            let contexts = day.allBlocks.flatMap { block in
                block.assignments.compactMap { AssignmentPracticeContext(day: day, blockID: block.id, assignmentID: $0.id) }
            }
            #expect(contexts.count == (number == 7 ? 0 : 1))
            if let context = contexts.first {
                #expect(context.recordContext.blockID == day.morningBlocks.first(where: { $0.category == .sightReading })?.id)
            }
        }
    }
}

nonisolated enum AssignmentFixtures {
    static func day(source: String = "generated-sight-reading-current-range", category: PracticeCategory = .sightReading) -> TodayLoadedState {
        TodayLoadedState(
            programme: TodayProgrammeSummary(programmeID: PracticeProgrammeID("programme-opaque")!, programmeVersion: 7, title: "Programme"),
            weekID: ProgrammeWeekID("opaque-week")!, weekTitle: "Week 1",
            dayID: PracticeDayID("opaque-day")!, dayTitle: "Day 1", dayKind: .practice,
            suggestedSessionSlot: .morning, localDayKey: "2026-09-27",
            morningBlocks: [TodayPracticeBlockState(id: PracticeBlockID("opaque-block")!, title: "Reading", category: category,
                sessionSlot: .morning, targetDurationMinutes: 10, isSuggested: true,
                assignments: [TodayAssignmentState(id: PracticeAssignmentID("opaque-assignment")!, title: "Reading assignment",
                    goal: "Read steadily", sourceID: ExerciseSourceID(source)!, sourceTitle: "Generated reading",
                    completionStatus: .notStarted, masteryState: nil, referenceMaterial: .unknownSource)])],
            eveningBlocks: [], recoveryBlocks: [])
    }

    static var context: AssignmentPracticeContext {
        let day = day()
        return AssignmentPracticeContext(day: day, blockID: day.morningBlocks[0].id,
                                         assignmentID: day.morningBlocks[0].assignments[0].id)!
    }
}
