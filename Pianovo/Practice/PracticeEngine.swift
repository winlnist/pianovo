nonisolated enum PracticeMode: String, CaseIterable, Hashable {
    case trebleReading = "Treble Reading"
    case bassReading = "Bass Reading"

    var clef: Clef {
        switch self {
        case .trebleReading:
            .treble
        case .bassReading:
            .bass
        }
    }

    var defaultPitchRange: PitchRange {
        switch self {
        case .trebleReading:
            PitchRange(lowerBound: Pitch(.c, octave: 4), upperBound: Pitch(.c, octave: 6))!
        case .bassReading:
            PitchRange(lowerBound: Pitch(.c, octave: 2), upperBound: Pitch(.c, octave: 4))!
        }
    }

    var supportedPitchRange: PitchRange {
        defaultPitchRange
    }
}

nonisolated struct PracticeConfiguration: Hashable {
    static let defaultMeasureCount = 16
    static let defaultEventsPerMeasure = 4

    let pitchRange: PitchRange
    let mode: PracticeMode
    let measureCount: Int
    let eventsPerMeasure: Int

    init(
        pitchRange: PitchRange,
        mode: PracticeMode = .trebleReading,
        measureCount: Int = PracticeConfiguration.defaultMeasureCount,
        eventsPerMeasure: Int = PracticeConfiguration.defaultEventsPerMeasure
    ) {
        self.pitchRange = pitchRange
        self.mode = mode
        self.measureCount = max(1, measureCount)
        self.eventsPerMeasure = max(1, eventsPerMeasure)
    }

    var eligiblePitches: [Pitch] {
        let supportedRange = mode.supportedPitchRange
        let naturalPitches = pitchRange.pitches.filter {
            $0.accidental == .natural && supportedRange.contains($0)
        }
        if !naturalPitches.isEmpty {
            return naturalPitches
        }

        let supportedPitches = pitchRange.pitches.filter { supportedRange.contains($0) }
        return supportedPitches.isEmpty ? supportedRange.pitches.filter { $0.accidental == .natural } : supportedPitches
    }
}

nonisolated struct ReadingEvent: Identifiable, Hashable {
    let id: MusicEventID
    let expectedPitches: [Pitch]

    init(id: MusicEventID, expectedPitches: [Pitch]) {
        precondition(!expectedPitches.isEmpty, "A reading event needs at least one expected pitch.")
        self.id = id
        self.expectedPitches = expectedPitches
    }

    init(id: MusicEventID, expectedPitch: Pitch) {
        self.init(id: id, expectedPitches: [expectedPitch])
    }

    var expectedPitch: Pitch {
        expectedPitches[0]
    }
}

typealias PracticePrompt = ReadingEvent

nonisolated struct ReadingMeasure: Identifiable, Hashable {
    let id: String
    let number: Int
    let events: [ReadingEvent]
}

nonisolated struct ReadingExercise: Identifiable, Hashable {
    let id: String
    let mode: PracticeMode
    let measures: [ReadingMeasure]

    var events: [ReadingEvent] {
        measures.flatMap(\.events)
    }
}

nonisolated enum PracticeInput: Hashable {
    case playedPitch(Pitch)
    case notePressed(Pitch)
}

nonisolated enum AnswerOutcome: Hashable {
    case correct
    case incorrect
}

nonisolated struct AnswerResult: Hashable {
    let outcome: AnswerOutcome
    let promptID: MusicEventID
    let expectedPitch: Pitch
    let playedPitch: Pitch
    let completedExercise: Bool

    var isCorrect: Bool {
        outcome == .correct
    }
}

nonisolated struct PracticeStatistics: Hashable {
    private(set) var correctAnswers = 0
    private(set) var incorrectAttempts = 0
    private(set) var totalAttempts = 0
    private(set) var promptsCompleted = 0
    private(set) var currentStreak = 0

    var accuracyPercentage: Double {
        guard totalAttempts > 0 else {
            return 0
        }

        return (Double(correctAnswers) / Double(totalAttempts)) * 100
    }

    mutating func recordCorrectAnswer() {
        correctAnswers += 1
        totalAttempts += 1
        promptsCompleted += 1
        currentStreak += 1
    }

    mutating func recordIncorrectAttempt() {
        incorrectAttempts += 1
        totalAttempts += 1
        currentStreak = 0
    }
}

struct ReadingExerciseGenerator {
    private let eligiblePitches: [Pitch]
    private let configuration: PracticeConfiguration
    private var nextIndex: (Int) -> Int
    private var exerciseCounter = 0

    init(configuration: PracticeConfiguration, nextIndex: @escaping (Int) -> Int = { upperBound in Int.random(in: 0..<upperBound) }) {
        self.eligiblePitches = configuration.eligiblePitches
        self.configuration = configuration
        self.nextIndex = nextIndex
    }

    mutating func nextExercise(avoiding previousPitch: Pitch? = nil) -> ReadingExercise {
        precondition(!eligiblePitches.isEmpty, "Reading exercise generation requires at least one eligible pitch.")

        exerciseCounter += 1
        var lastPitch = previousPitch
        var measures: [ReadingMeasure] = []

        for measureIndex in 0..<configuration.measureCount {
            var events: [ReadingEvent] = []

            for eventIndex in 0..<configuration.eventsPerMeasure {
                let pitch = nextPitch(avoiding: lastPitch)
                lastPitch = pitch
                events.append(
                    ReadingEvent(
                        id: MusicEventID(rawValue: "exercise-\(exerciseCounter)-measure-\(measureIndex + 1)-event-\(eventIndex + 1)"),
                        expectedPitch: pitch
                    )
                )
            }

            measures.append(
                ReadingMeasure(
                    id: "exercise-\(exerciseCounter)-measure-\(measureIndex + 1)",
                    number: measureIndex + 1,
                    events: events
                )
            )
        }

        return ReadingExercise(
            id: "exercise-\(exerciseCounter)",
            mode: configuration.mode,
            measures: measures
        )
    }

    private mutating func nextPitch(avoiding previousPitch: Pitch?) -> Pitch {
        guard eligiblePitches.count > 1 else {
            return eligiblePitches[0]
        }

        let firstIndex = normalizedIndex(nextIndex(eligiblePitches.count), upperBound: eligiblePitches.count)
        let firstPitch = eligiblePitches[firstIndex]

        guard firstPitch == previousPitch else {
            return firstPitch
        }

        let fallbackIndex = (firstIndex + 1) % eligiblePitches.count
        return eligiblePitches[fallbackIndex]
    }

    private func normalizedIndex(_ index: Int, upperBound: Int) -> Int {
        let remainder = index % upperBound
        return remainder >= 0 ? remainder : remainder + upperBound
    }
}

struct PracticeSession {
    let configuration: PracticeConfiguration
    private(set) var exercise: ReadingExercise
    private(set) var currentEventIndex = 0
    private(set) var statistics = PracticeStatistics()
    private(set) var mostRecentAnswer: AnswerResult?
    private var exerciseGenerator: ReadingExerciseGenerator

    init(configuration: PracticeConfiguration, exerciseGenerator: ReadingExerciseGenerator? = nil) {
        self.configuration = configuration

        var generator = exerciseGenerator ?? ReadingExerciseGenerator(configuration: configuration)
        self.exercise = generator.nextExercise()
        self.exerciseGenerator = generator
    }

    init(configuration: PracticeConfiguration, exercise: ReadingExercise, exerciseGenerator: ReadingExerciseGenerator? = nil) {
        self.configuration = configuration
        self.exercise = exercise
        self.exerciseGenerator = exerciseGenerator ?? ReadingExerciseGenerator(configuration: configuration)
    }

    var currentPrompt: PracticePrompt {
        exercise.events[currentEventIndex]
    }

    var isOnFinalEvent: Bool {
        currentEventIndex == exercise.events.count - 1
    }

    mutating func submit(_ input: PracticeInput) -> AnswerResult {
        switch input {
        case .playedPitch(let pitch), .notePressed(let pitch):
            return submit(playedPitch: pitch)
        }
    }

    mutating func submit(playedPitch: Pitch) -> AnswerResult {
        let prompt = currentPrompt
        let outcome: AnswerOutcome = prompt.expectedPitches == [playedPitch] ? .correct : .incorrect
        let completedExercise = outcome == .correct && isOnFinalEvent
        let result = AnswerResult(
            outcome: outcome,
            promptID: prompt.id,
            expectedPitch: prompt.expectedPitch,
            playedPitch: playedPitch,
            completedExercise: completedExercise
        )

        switch outcome {
        case .correct:
            statistics.recordCorrectAnswer()
            if completedExercise {
                exercise = exerciseGenerator.nextExercise(avoiding: prompt.expectedPitch)
                currentEventIndex = 0
            } else {
                currentEventIndex += 1
            }
        case .incorrect:
            statistics.recordIncorrectAttempt()
        }

        mostRecentAnswer = result
        return result
    }
}
