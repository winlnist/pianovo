import Testing
@testable import Sightlink_Piano

struct ProgrammeSeedDataTests {
    @Test func pianovoSeedPassesGeneralValidationAndPianovoPolicy() {
        let seed = PianovoProgrammeSeedData.twelveWeekProgramme()

        let generalIssues = ProgrammeValidator().validate(
            seed.programme,
            sourceCatalogue: seed.sourceCatalogue
        )
        let policyIssues = PianovoProgrammePolicyValidator().validate(seed.programme)

        #expect(generalIssues.isEmpty)
        #expect(policyIssues.isEmpty)
    }

    @Test func pianovoSeedHasTwelveWeeksWithSixPracticeDaysAndOneRecoveryDay() {
        let programme = PianovoProgrammeSeedData.twelveWeekProgramme().programme

        #expect(programme.weeks.count == 12)
        #expect(programme.weeks.allSatisfy { $0.days.count == 7 })
        #expect(programme.weeks.allSatisfy { $0.days.filter { $0.kind == .practice }.count == 6 })
        #expect(programme.weeks.allSatisfy { $0.days.filter { $0.kind == .recoveryReflection }.count == 1 })
    }

    @Test func practiceDaysUseApproximateFortyFiveMinuteMorningAndEveningSessions() {
        let programme = PianovoProgrammeSeedData.twelveWeekProgramme().programme
        let practiceDays = programme.weeks.flatMap(\.days).filter { $0.kind == .practice }

        #expect(practiceDays.allSatisfy { day in
            day.blocks
                .filter { $0.sessionSlot == .morning }
                .map(\.targetDurationMinutes)
                .reduce(0, +) == 45
        })
        #expect(practiceDays.allSatisfy { day in
            day.blocks
                .filter { $0.sessionSlot == .evening }
                .map(\.targetDurationMinutes)
                .reduce(0, +) == 45
        })
    }

    @Test func weekOneBeginsWithBeyerNumberSixtyThree() {
        let seed = PianovoProgrammeSeedData.twelveWeekProgramme()
        let weekOneSources = sourceReferences(in: [seed.programme.weeks[0]], catalogue: seed.sourceCatalogue)

        #expect(weekOneSources.contains { $0.kind == .beyer && $0.beyerExerciseNumber == 63 })
    }

    @Test func laterWeeksDoNotPreassignLaterNumberedBeyerExercises() {
        let seed = PianovoProgrammeSeedData.twelveWeekProgramme()
        let laterWeekSources = sourceReferences(in: Array(seed.programme.weeks.dropFirst()), catalogue: seed.sourceCatalogue)

        #expect(!laterWeekSources.contains { ($0.beyerExerciseNumber ?? 0) > 63 })
        #expect(laterWeekSources.filter { $0.kind == .beyer }.allSatisfy { $0.beyerExerciseNumber == nil })
    }

    @Test func seedIdentifiersAreDeterministic() {
        let first = PianovoProgrammeSeedData.twelveWeekProgramme().programme
        let second = PianovoProgrammeSeedData.twelveWeekProgramme().programme

        #expect(first.id == second.id)
        #expect(first.weeks.map(\.id) == second.weeks.map(\.id))
        #expect(first.weeks.flatMap(\.days).map(\.id) == second.weeks.flatMap(\.days).map(\.id))
        #expect(first.weeks.flatMap(\.days).flatMap(\.blocks).map(\.id) == second.weeks.flatMap(\.days).flatMap(\.blocks).map(\.id))
    }

    private func sourceReferences(
        in weeks: [ProgrammeWeek],
        catalogue: ExerciseSourceCatalogue
    ) -> [ExerciseSource] {
        weeks
            .flatMap(\.days)
            .flatMap(\.blocks)
            .flatMap(\.assignments)
            .compactMap { catalogue.source(withID: $0.sourceID) }
    }
}
