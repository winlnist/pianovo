import Testing
@testable import Sightlink_Piano

struct ProgrammeValidationTests {
    @Test func generalValidationIsSeparateFromPianovoPolicy() throws {
        let fixture = try makeFixture()

        let generalIssues = ProgrammeValidator().validate(
            fixture.programme,
            sourceCatalogue: fixture.sourceCatalogue
        )
        let pianovoIssues = PianovoProgrammePolicyValidator().validate(fixture.programme)

        #expect(generalIssues.isEmpty)
        #expect(pianovoIssues.contains { $0.code == .invalidProgrammeLength })
        #expect(pianovoIssues.contains { $0.code == .invalidWeekShape })
    }

    @Test func duplicateAssignmentIDsAreDetected() throws {
        var fixture = try makeFixture()
        let duplicateAssignmentID = try #require(PracticeAssignmentID("duplicate-assignment"))
        let sourceID = try #require(ExerciseSourceID("fixture-source"))

        let assignments = [
            PracticeAssignment(
                id: duplicateAssignmentID,
                title: "First",
                sourceID: sourceID,
                goal: "Play calmly.",
                masteryRuleID: nil,
                remediationOnly: false
            ),
            PracticeAssignment(
                id: duplicateAssignmentID,
                title: "Second",
                sourceID: sourceID,
                goal: "Repeat evenly.",
                masteryRuleID: nil,
                remediationOnly: false
            )
        ]

        fixture.programme = try fixture.replacingAssignments(assignments)

        let issues = ProgrammeValidator().validate(
            fixture.programme,
            sourceCatalogue: fixture.sourceCatalogue
        )

        #expect(issues.contains { $0.code == .duplicateID && $0.path.contains("assignments") })
    }

    @Test func sourceReferencesResolveAgainstExplicitCatalogue() throws {
        let fixture = try makeFixture()
        let otherCatalogue = ExerciseSourceCatalogue(sources: [
            ExerciseSource(
                id: try #require(ExerciseSourceID("other-source")),
                kind: .review,
                collectionTitle: nil,
                exerciseIdentifier: nil,
                displayTitle: "Other source",
                beyerExerciseNumber: nil
            )
        ])

        let issues = ProgrammeValidator().validate(
            fixture.programme,
            sourceCatalogue: otherCatalogue
        )

        #expect(issues.contains { $0.code == .unresolvedSourceReference })
    }

    @Test func nonPositiveDurationsAreStructuredValidationIssues() throws {
        var fixture = try makeFixture()
        fixture.programme = try fixture.replacingBlockDuration(0)

        let issues = ProgrammeValidator().validate(
            fixture.programme,
            sourceCatalogue: fixture.sourceCatalogue
        )

        #expect(issues.contains { $0.code == .invalidDuration })
    }

    private func makeFixture() throws -> ProgrammeFixture {
        let sourceID = try #require(ExerciseSourceID("fixture-source"))
        let sourceCatalogue = ExerciseSourceCatalogue(sources: [
            ExerciseSource(
                id: sourceID,
                kind: .technique,
                collectionTitle: nil,
                exerciseIdentifier: nil,
                displayTitle: "Fixture source",
                beyerExerciseNumber: nil
            )
        ])
        let assignment = PracticeAssignment(
            id: try #require(PracticeAssignmentID("assignment-1")),
            title: "Assignment",
            sourceID: sourceID,
            goal: "Play with control.",
            masteryRuleID: nil,
            remediationOnly: false
        )
        let block = PracticeBlock(
            id: try #require(PracticeBlockID("block-1")),
            title: "Technique",
            category: .technique,
            sessionSlot: .morning,
            targetDurationMinutes: 10,
            assignments: [assignment]
        )
        let day = PracticeDay(
            id: try #require(PracticeDayID("day-1")),
            weekNumber: 1,
            dayNumber: 1,
            kind: .practice,
            blocks: [block]
        )
        let week = ProgrammeWeek(
            id: try #require(ProgrammeWeekID("week-1")),
            number: 1,
            title: "Week 1",
            days: [day]
        )
        let programme = PracticeProgramme(
            id: try #require(PracticeProgrammeID("programme-1")),
            title: "Generic Programme",
            progressionPrinciple: [.quality],
            weeks: [week],
            masteryRules: []
        )

        return ProgrammeFixture(programme: programme, sourceCatalogue: sourceCatalogue)
    }
}

private struct ProgrammeFixture {
    var programme: PracticeProgramme
    let sourceCatalogue: ExerciseSourceCatalogue

    func replacingAssignments(_ assignments: [PracticeAssignment]) throws -> PracticeProgramme {
        try replacingBlock(
            PracticeBlock(
                id: try #require(PracticeBlockID("block-1")),
                title: "Technique",
                category: .technique,
                sessionSlot: .morning,
                targetDurationMinutes: 10,
                assignments: assignments
            )
        )
    }

    func replacingBlockDuration(_ minutes: Int) throws -> PracticeProgramme {
        try replacingBlock(
            PracticeBlock(
                id: try #require(PracticeBlockID("block-1")),
                title: "Technique",
                category: .technique,
                sessionSlot: .morning,
                targetDurationMinutes: minutes,
                assignments: programme.weeks[0].days[0].blocks[0].assignments
            )
        )
    }

    private func replacingBlock(_ block: PracticeBlock) throws -> PracticeProgramme {
        let day = PracticeDay(
            id: programme.weeks[0].days[0].id,
            weekNumber: 1,
            dayNumber: 1,
            kind: .practice,
            blocks: [block]
        )
        let week = ProgrammeWeek(
            id: programme.weeks[0].id,
            number: 1,
            title: "Week 1",
            days: [day]
        )

        return PracticeProgramme(
            id: programme.id,
            title: programme.title,
            progressionPrinciple: programme.progressionPrinciple,
            weeks: [week],
            masteryRules: programme.masteryRules
        )
    }
}
