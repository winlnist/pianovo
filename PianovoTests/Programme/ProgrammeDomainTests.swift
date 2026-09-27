import Testing
@testable import Pianovo

struct ProgrammeDomainTests {
    @Test func stableIDInitializersRejectEmptyValues() {
        #expect(PracticeProgrammeID("") == nil)
        #expect(ProgrammeWeekID(" ") == nil)
        #expect(PracticeDayID("\n") == nil)
        #expect(PracticeBlockID("") == nil)
        #expect(PracticeAssignmentID(" ") == nil)
        #expect(ExerciseSourceID("\t") == nil)
        #expect(MasteryRuleID("") == nil)
    }

    @Test func masteryStateDoesNotModelManualOverrideAsLearningState() {
        #expect(MasteryState.allCases == [
            .learning,
            .stabilizing,
            .nearlyMastered,
            .mastered
        ])
        #expect(!MasteryState.allCases.map(\.rawValue).contains("overridden"))
    }

    @Test func masteryRuleKeepsOverridePermissionSeparateFromState() throws {
        let rule = MasteryRule(
            id: try #require(MasteryRuleID("rule-beyer-v1")),
            version: 1,
            title: "Beyer control",
            criteria: [
                .qualifyingAttempts(count: 3, onSeparatePracticeDays: true),
                .teacherOrUserOverrideAllowed
            ],
            allowsManualOverride: true
        )

        #expect(rule.allowsManualOverride)
        #expect(rule.criteria.contains(.teacherOrUserOverrideAllowed))
        #expect(MasteryState.mastered.rawValue == "mastered")
    }
}
