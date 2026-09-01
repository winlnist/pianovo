import Testing
@testable import Sightlink_Piano

struct PracticeEngineTests {
    @Test func exerciseGenerationCreatesRequestedMeasuresAndEvents() throws {
        let range = try #require(PitchRange(lowerBound: Pitch(.c, octave: 4), upperBound: Pitch(.g, octave: 4)))
        let configuration = PracticeConfiguration(pitchRange: range, mode: .trebleReading, measureCount: 3, eventsPerMeasure: 4)
        var indexes = Array(0..<12)
        var generator = ReadingExerciseGenerator(configuration: configuration) { _ in indexes.removeFirst() }

        let exercise = generator.nextExercise()

        #expect(exercise.mode == .trebleReading)
        #expect(exercise.measures.count == 3)
        #expect(exercise.events.count == 12)
        #expect(exercise.measures.allSatisfy { $0.events.count == 4 })
        #expect(exercise.events.allSatisfy { range.contains($0.expectedPitch) })
    }

    @Test func trebleModeUsesCompatibleConfiguredTrebleRange() throws {
        let range = try #require(PitchRange(lowerBound: Pitch(.c, octave: 2), upperBound: Pitch(.c, octave: 6)))
        let configuration = PracticeConfiguration(pitchRange: range, mode: .trebleReading, measureCount: 1, eventsPerMeasure: 8)
        var generator = ReadingExerciseGenerator(configuration: configuration) { _ in 0 }

        let exercise = generator.nextExercise()

        #expect(exercise.events.allSatisfy { PracticeMode.trebleReading.supportedPitchRange.contains($0.expectedPitch) })
    }

    @Test func bassModeUsesCompatibleConfiguredBassRange() throws {
        let range = try #require(PitchRange(lowerBound: Pitch(.c, octave: 2), upperBound: Pitch(.c, octave: 6)))
        let configuration = PracticeConfiguration(pitchRange: range, mode: .bassReading, measureCount: 1, eventsPerMeasure: 8)
        var generator = ReadingExerciseGenerator(configuration: configuration) { _ in 0 }

        let exercise = generator.nextExercise()

        #expect(exercise.events.allSatisfy { PracticeMode.bassReading.supportedPitchRange.contains($0.expectedPitch) })
    }

    @Test func normalMultiPitchRangeDoesNotCollapseToAllC() throws {
        let range = try #require(PitchRange(lowerBound: Pitch(.c, octave: 4), upperBound: Pitch(.c, octave: 5)))
        let configuration = PracticeConfiguration(pitchRange: range, mode: .trebleReading, measureCount: 2, eventsPerMeasure: 4)
        var generator = ReadingExerciseGenerator(configuration: configuration) { _ in 0 }

        let exercise = generator.nextExercise()

        #expect(configuration.eligiblePitches.count > 1)
        #expect(Set(exercise.events.map(\.expectedPitch)).count > 1)
        #expect(exercise.events.map(\.expectedPitch) != Array(repeating: Pitch(.c, octave: 4), count: exercise.events.count))
    }

    @Test func deterministicGenerationWorksInTests() throws {
        let range = try #require(PitchRange(lowerBound: Pitch(.c, octave: 4), upperBound: Pitch(.g, octave: 4)))
        let configuration = PracticeConfiguration(pitchRange: range, mode: .trebleReading, measureCount: 1, eventsPerMeasure: 5)
        var indexes = [0, 1, 2, 3, 4]
        var generator = ReadingExerciseGenerator(configuration: configuration) { _ in indexes.removeFirst() }

        let exercise = generator.nextExercise()

        #expect(exercise.events.map(\.expectedPitch) == [
            Pitch(.c, octave: 4),
            Pitch(.d, octave: 4),
            Pitch(.e, octave: 4),
            Pitch(.f, octave: 4),
            Pitch(.g, octave: 4)
        ])
    }

    @Test func immediateRepeatAvoidanceUsesNextEligiblePitchWhenAlternativesExist() throws {
        let range = try #require(PitchRange(lowerBound: Pitch(.c, octave: 4), upperBound: Pitch(.e, octave: 4)))
        let configuration = PracticeConfiguration(pitchRange: range, mode: .trebleReading, measureCount: 1, eventsPerMeasure: 2)
        var generator = ReadingExerciseGenerator(configuration: configuration) { _ in 0 }

        let exercise = generator.nextExercise()

        #expect(exercise.events.map(\.expectedPitch) == [
            Pitch(.c, octave: 4),
            Pitch(.d, octave: 4)
        ])
    }

    @Test func singlePitchRangeCanRepeat() throws {
        let onlyPitch = Pitch(.c, octave: 4)
        let range = try #require(PitchRange(lowerBound: onlyPitch, upperBound: onlyPitch))
        let configuration = PracticeConfiguration(pitchRange: range, mode: .trebleReading, measureCount: 1, eventsPerMeasure: 2)
        var generator = ReadingExerciseGenerator(configuration: configuration) { _ in 0 }

        #expect(generator.nextExercise().events.map(\.expectedPitch) == [onlyPitch, onlyPitch])
    }

    @Test func progressionWalksOrderedEventsAndKeepsIndexOnWrongAnswer() throws {
        let session = try makeSessionForCDEFMelody()
        var mutableSession = session

        #expect(mutableSession.currentEventIndex == 0)
        #expect(mutableSession.submit(playedPitch: Pitch(.c, octave: 4)).outcome == .correct)
        #expect(mutableSession.currentEventIndex == 1)
        #expect(mutableSession.submit(playedPitch: Pitch(.d, octave: 4)).outcome == .correct)
        #expect(mutableSession.currentEventIndex == 2)
        #expect(mutableSession.submit(playedPitch: Pitch(.g, octave: 4)).outcome == .incorrect)
        #expect(mutableSession.currentEventIndex == 2)
        #expect(mutableSession.submit(playedPitch: Pitch(.e, octave: 4)).outcome == .correct)
        #expect(mutableSession.currentEventIndex == 3)

        let finalResult = mutableSession.submit(playedPitch: Pitch(.f, octave: 4))

        #expect(finalResult.outcome == .correct)
        #expect(finalResult.completedExercise)
        #expect(mutableSession.currentEventIndex == 0)
        #expect(mutableSession.exercise.id == "exercise-1")
    }

    @Test func statisticsSemanticsRemainCorrectAcrossMultiEventExercise() throws {
        var session = try makeSessionForCDEFMelody()

        _ = session.submit(playedPitch: Pitch(.c, octave: 4))
        _ = session.submit(playedPitch: Pitch(.g, octave: 4))
        _ = session.submit(playedPitch: Pitch(.d, octave: 4))

        #expect(session.statistics.correctAnswers == 2)
        #expect(session.statistics.incorrectAttempts == 1)
        #expect(session.statistics.totalAttempts == 3)
        #expect(session.statistics.promptsCompleted == 2)
        #expect(session.statistics.currentStreak == 1)
        #expect(session.statistics.accuracyPercentage.rounded() == 67)
    }

    @Test func regenerationPreservesConfigurationAndResetsCursorAfterFinalEvent() throws {
        var session = try makeSessionForCDEFMelody()
        let configuration = session.configuration

        _ = session.submit(playedPitch: Pitch(.c, octave: 4))
        _ = session.submit(playedPitch: Pitch(.d, octave: 4))
        _ = session.submit(playedPitch: Pitch(.e, octave: 4))
        _ = session.submit(playedPitch: Pitch(.f, octave: 4))

        #expect(session.configuration == configuration)
        #expect(session.currentEventIndex == 0)
        #expect(session.exercise.mode == configuration.mode)
        #expect(session.exercise.measures.count == configuration.measureCount)
        #expect(session.exercise.events.count == configuration.measureCount * configuration.eventsPerMeasure)
    }

    @Test func accuracyHandlesZeroAndNonZeroAttemptsSafely() {
        var statistics = PracticeStatistics()

        #expect(statistics.accuracyPercentage == 0)

        statistics.recordCorrectAnswer()
        #expect(statistics.accuracyPercentage == 100)

        statistics.recordIncorrectAttempt()
        #expect(statistics.accuracyPercentage == 50)
    }

    @Test func streakSemanticsResetOnWrongAndIncrementOnCorrect() {
        var statistics = PracticeStatistics()

        statistics.recordCorrectAnswer()
        statistics.recordCorrectAnswer()
        #expect(statistics.currentStreak == 2)

        statistics.recordIncorrectAttempt()
        #expect(statistics.currentStreak == 0)

        statistics.recordCorrectAnswer()
        #expect(statistics.currentStreak == 1)
    }

    @Test func completedPromptCountIsIndependentFromIncorrectAttempts() {
        var statistics = PracticeStatistics()

        statistics.recordIncorrectAttempt()
        statistics.recordIncorrectAttempt()
        #expect(statistics.promptsCompleted == 0)

        statistics.recordCorrectAnswer()
        #expect(statistics.promptsCompleted == 1)
    }

    private func makeSessionForCDEFMelody() throws -> PracticeSession {
        let range = try #require(PitchRange(lowerBound: Pitch(.c, octave: 4), upperBound: Pitch(.g, octave: 4)))
        let configuration = PracticeConfiguration(pitchRange: range, mode: .trebleReading, measureCount: 1, eventsPerMeasure: 4)
        let exercise = ReadingExercise(
            id: "fixture",
            mode: .trebleReading,
            measures: [
                ReadingMeasure(
                    id: "fixture-measure-1",
                    number: 1,
                    events: [
                        ReadingEvent(id: MusicEventID(rawValue: "fixture-1"), expectedPitch: Pitch(.c, octave: 4)),
                        ReadingEvent(id: MusicEventID(rawValue: "fixture-2"), expectedPitch: Pitch(.d, octave: 4)),
                        ReadingEvent(id: MusicEventID(rawValue: "fixture-3"), expectedPitch: Pitch(.e, octave: 4)),
                        ReadingEvent(id: MusicEventID(rawValue: "fixture-4"), expectedPitch: Pitch(.f, octave: 4))
                    ]
                )
            ]
        )
        var indexes = [0, 1, 2, 3]
        let generator = ReadingExerciseGenerator(configuration: configuration) { _ in indexes.removeFirst() }

        return PracticeSession(configuration: configuration, exercise: exercise, exerciseGenerator: generator)
    }
}
