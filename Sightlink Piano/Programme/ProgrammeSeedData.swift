import Foundation

nonisolated struct ProgrammeSeed {
    let programme: PracticeProgramme
    let sourceCatalogue: ExerciseSourceCatalogue
}

nonisolated enum PianovoProgrammeSeedData {
    static func twelveWeekProgramme() -> ProgrammeSeed {
        let masteryRuleID = masteryRuleID("mastery-rule-beyer-control-v1")
        let sourceCatalogue = ExerciseSourceCatalogue(sources: sources)
        let programme = PracticeProgramme(
            id: programmeID("programme-pianovo-twelve-week-v1"),
            title: "Pianovo Twelve-Week Programme",
            progressionPrinciple: [.quality, .consistency, .fluency, .speed],
            weeks: (1...12).map { week(number: $0, masteryRuleID: masteryRuleID) },
            masteryRules: [
                MasteryRule(
                    id: masteryRuleID,
                    version: 1,
                    title: "Controlled Beyer mastery",
                    criteria: [
                        .qualifyingAttempts(count: 3, onSeparatePracticeDays: true),
                        .teacherOrUserOverrideAllowed
                    ],
                    allowsManualOverride: true
                )
            ]
        )

        return ProgrammeSeed(programme: programme, sourceCatalogue: sourceCatalogue)
    }

    private static let sources: [ExerciseSource] = [
        ExerciseSource(
            id: sourceID("warm-up-general-control"),
            kind: .warmUp,
            collectionTitle: nil,
            exerciseIdentifier: nil,
            displayTitle: "Warm-up for relaxed control",
            beyerExerciseNumber: nil
        ),
        ExerciseSource(
            id: sourceID("technique-daily-control"),
            kind: .technique,
            collectionTitle: nil,
            exerciseIdentifier: nil,
            displayTitle: "Daily technique for evenness",
            beyerExerciseNumber: nil
        ),
        ExerciseSource(
            id: sourceID("beyer-op101-no-63"),
            kind: .beyer,
            collectionTitle: "Beyer Op. 101",
            exerciseIdentifier: "No. 63",
            displayTitle: "Beyer Op. 101 No. 63",
            beyerExerciseNumber: 63
        ),
        ExerciseSource(
            id: sourceID("beyer-op101-current-sequence"),
            kind: .beyer,
            collectionTitle: "Beyer Op. 101",
            exerciseIdentifier: "Current mastered-sequence exercise",
            displayTitle: "Current Beyer sequence exercise",
            beyerExerciseNumber: nil
        ),
        ExerciseSource(
            id: sourceID("repertoire-harmony-general"),
            kind: .repertoireHarmony,
            collectionTitle: nil,
            exerciseIdentifier: nil,
            displayTitle: "Repertoire and harmony study",
            beyerExerciseNumber: nil
        ),
        ExerciseSource(
            id: sourceID("generated-sight-reading-current-range"),
            kind: .sightReading,
            collectionTitle: "Generated sight-reading",
            exerciseIdentifier: "Current configured range",
            displayTitle: "Generated sight-reading in the current range",
            beyerExerciseNumber: nil
        ),
        ExerciseSource(
            id: sourceID("review-practice-notes"),
            kind: .review,
            collectionTitle: nil,
            exerciseIdentifier: nil,
            displayTitle: "Practice review notes",
            beyerExerciseNumber: nil
        ),
        ExerciseSource(
            id: sourceID("reflection-recovery-day"),
            kind: .reflection,
            collectionTitle: nil,
            exerciseIdentifier: nil,
            displayTitle: "Recovery and reflection",
            beyerExerciseNumber: nil
        )
    ]

    private static func week(number: Int, masteryRuleID: MasteryRuleID) -> ProgrammeWeek {
        ProgrammeWeek(
            id: weekID(String(format: "week-%02d", number)),
            number: number,
            title: "Week \(number)",
            days: (1...7).map { day(weekNumber: number, dayNumber: $0, masteryRuleID: masteryRuleID) }
        )
    }

    private static func day(
        weekNumber: Int,
        dayNumber: Int,
        masteryRuleID: MasteryRuleID
    ) -> PracticeDay {
        let isRecoveryDay = dayNumber == 7
        return PracticeDay(
            id: dayID(String(format: "week-%02d-day-%02d", weekNumber, dayNumber)),
            weekNumber: weekNumber,
            dayNumber: dayNumber,
            kind: isRecoveryDay ? .recoveryReflection : .practice,
            blocks: isRecoveryDay
                ? recoveryBlocks(weekNumber: weekNumber, dayNumber: dayNumber)
                : practiceBlocks(weekNumber: weekNumber, dayNumber: dayNumber, masteryRuleID: masteryRuleID)
        )
    }

    private static func practiceBlocks(
        weekNumber: Int,
        dayNumber: Int,
        masteryRuleID: MasteryRuleID
    ) -> [PracticeBlock] {
        [
            block(
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                key: "morning-warm-up",
                title: "Warm-up",
                category: .warmUp,
                slot: .morning,
                minutes: 10,
                sourceID: "warm-up-general-control",
                goal: "Start with relaxed movement and clear tone preparation."
            ),
            block(
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                key: "morning-technique",
                title: "Technique",
                category: .technique,
                slot: .morning,
                minutes: 10,
                sourceID: "technique-daily-control",
                goal: "Prioritize control before speed."
            ),
            block(
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                key: "morning-beyer",
                title: "Beyer",
                category: .beyer,
                slot: .morning,
                minutes: 15,
                sourceID: beyerSourceID(forWeek: weekNumber),
                goal: "Work only within the current Beyer sequence.",
                masteryRuleID: masteryRuleID
            ),
            block(
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                key: "morning-sight-reading",
                title: "Sight-reading",
                category: .sightReading,
                slot: .morning,
                minutes: 10,
                sourceID: "generated-sight-reading-current-range",
                goal: "Read steadily without guessing."
            ),
            block(
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                key: "evening-technique",
                title: "Technique",
                category: .technique,
                slot: .evening,
                minutes: 10,
                sourceID: "technique-daily-control",
                goal: "Repeat slowly enough to stay even."
            ),
            block(
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                key: "evening-harmony",
                title: "Repertoire and harmony",
                category: .repertoireHarmony,
                slot: .evening,
                minutes: 15,
                sourceID: "repertoire-harmony-general",
                goal: "Connect musical understanding to the keyboard."
            ),
            block(
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                key: "evening-beyer",
                title: "Beyer review",
                category: .beyer,
                slot: .evening,
                minutes: 15,
                sourceID: beyerSourceID(forWeek: weekNumber),
                goal: "Repeat the current Beyer material only when quality is stable.",
                masteryRuleID: masteryRuleID
            ),
            block(
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                key: "evening-review",
                title: "Review",
                category: .review,
                slot: .evening,
                minutes: 5,
                sourceID: "review-practice-notes",
                goal: "Record what improved and what needs the next attempt."
            )
        ]
    }

    private static func recoveryBlocks(weekNumber: Int, dayNumber: Int) -> [PracticeBlock] {
        [
            block(
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                key: "recovery-reflection",
                title: "Recovery and reflection",
                category: .reflection,
                slot: .recovery,
                minutes: 45,
                sourceID: "reflection-recovery-day",
                goal: "Reflect on consistency and decide what needs attention next."
            )
        ]
    }

    private static func block(
        weekNumber: Int,
        dayNumber: Int,
        key: String,
        title: String,
        category: PracticeCategory,
        slot: PracticeSessionSlot,
        minutes: Int,
        sourceID: String,
        goal: String,
        masteryRuleID: MasteryRuleID? = nil
    ) -> PracticeBlock {
        let blockID = String(format: "week-%02d-day-%02d-%@", weekNumber, dayNumber, key)
        return PracticeBlock(
            id: practiceBlockID(blockID),
            title: title,
            category: category,
            sessionSlot: slot,
            targetDurationMinutes: minutes,
            assignments: [
                PracticeAssignment(
                    id: assignmentID("\(blockID)-assignment"),
                    title: title,
                    sourceID: self.sourceID(sourceID),
                    goal: goal,
                    masteryRuleID: masteryRuleID,
                    remediationOnly: false
                )
            ]
        )
    }

    private static func beyerSourceID(forWeek weekNumber: Int) -> String {
        weekNumber == 1 ? "beyer-op101-no-63" : "beyer-op101-current-sequence"
    }

    private static func programmeID(_ rawValue: String) -> PracticeProgrammeID {
        PracticeProgrammeID(rawValue)!
    }

    private static func weekID(_ rawValue: String) -> ProgrammeWeekID {
        ProgrammeWeekID(rawValue)!
    }

    private static func dayID(_ rawValue: String) -> PracticeDayID {
        PracticeDayID(rawValue)!
    }

    private static func practiceBlockID(_ rawValue: String) -> PracticeBlockID {
        PracticeBlockID(rawValue)!
    }

    private static func assignmentID(_ rawValue: String) -> PracticeAssignmentID {
        PracticeAssignmentID(rawValue)!
    }

    private static func sourceID(_ rawValue: String) -> ExerciseSourceID {
        ExerciseSourceID(rawValue)!
    }

    private static func masteryRuleID(_ rawValue: String) -> MasteryRuleID {
        MasteryRuleID(rawValue)!
    }
}
