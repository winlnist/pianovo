import Combine
import Foundation

@MainActor
final class PracticeViewModel: ObservableObject {
    @Published private(set) var session: PracticeSession
    @Published private(set) var feedback = PracticeFeedback.neutral
    @Published private(set) var lowerPitch: Pitch
    @Published private(set) var upperPitch: Pitch
    @Published private(set) var mode: PracticeMode

    let allPitchOptions: [Pitch]

    init(
        initialMode: PracticeMode = .trebleReading,
        initialRange: PitchRange? = nil,
        pitchOptions: [Pitch] = PracticeViewModel.defaultPitchOptions
    ) {
        let range = initialRange ?? initialMode.defaultPitchRange
        self.mode = initialMode
        self.allPitchOptions = pitchOptions
        self.lowerPitch = range.lowerBound
        self.upperPitch = range.upperBound
        self.session = PracticeSession(configuration: PracticeConfiguration(pitchRange: range, mode: initialMode))
    }

    var currentPrompt: PracticePrompt {
        session.currentPrompt
    }

    var exercise: ReadingExercise {
        session.exercise
    }

    var currentEventIndex: Int {
        session.currentEventIndex
    }

    var statistics: PracticeStatistics {
        session.statistics
    }

    var selectedRangeLabel: String {
        "\(Self.pitchName(lowerPitch))-\(Self.pitchName(upperPitch))"
    }

    var pitchOptions: [Pitch] {
        let supportedRange = mode.supportedPitchRange
        return allPitchOptions.filter { supportedRange.contains($0) }
    }

    var progressLabel: String {
        "\(currentEventIndex + 1) of \(session.exercise.events.count)"
    }

    func submit(_ event: MIDIInputEvent) {
        guard let input = event.practiceInput else {
            return
        }

        submit(input)
    }

    func submit(_ input: PracticeInput) {
        let result = session.submit(input)
        feedback = PracticeFeedback(result: result)
    }

    func updateMode(_ mode: PracticeMode) {
        self.mode = mode
        let range = rangeForModeChange(to: mode)
        lowerPitch = range.lowerBound
        upperPitch = range.upperBound

        restartSession()
    }

    func updateLowerPitch(_ pitch: Pitch) {
        lowerPitch = clamp(pitch, to: mode.supportedPitchRange)

        if upperPitch < lowerPitch {
            upperPitch = lowerPitch
        }

        restartSession()
    }

    func updateUpperPitch(_ pitch: Pitch) {
        upperPitch = clamp(pitch, to: mode.supportedPitchRange)

        if upperPitch < lowerPitch {
            lowerPitch = upperPitch
        }

        restartSession()
    }

    func resetSession() {
        restartSession()
    }

    private func restartSession() {
        guard let range = PitchRange(lowerBound: lowerPitch, upperBound: upperPitch) else {
            return
        }

        session = PracticeSession(configuration: PracticeConfiguration(pitchRange: range, mode: mode))
        feedback = .neutral
    }

    private func rangeForModeChange(to mode: PracticeMode) -> PitchRange {
        let supportedRange = mode.supportedPitchRange
        let clampedLower = clamp(lowerPitch, to: supportedRange)
        let clampedUpper = clamp(upperPitch, to: supportedRange)

        guard
            let clampedRange = PitchRange(lowerBound: clampedLower, upperBound: clampedUpper),
            PracticeConfiguration(pitchRange: clampedRange, mode: mode).eligiblePitches.count > 1
        else {
            return mode.defaultPitchRange
        }

        return clampedRange
    }

    private func clamp(_ pitch: Pitch, to range: PitchRange) -> Pitch {
        if pitch < range.lowerBound {
            return range.lowerBound
        }

        if range.upperBound < pitch {
            return range.upperBound
        }

        return pitch
    }

    nonisolated static let defaultRange = PracticeMode.trebleReading.defaultPitchRange

    nonisolated static let defaultPitchOptions: [Pitch] = {
        let range = PitchRange(lowerBound: Pitch(.c, octave: 2), upperBound: Pitch(.c, octave: 6))!
        return range.pitches.filter { $0.accidental == .natural }
    }()

    static func pitchName(_ pitch: Pitch) -> String {
        let accidental: String

        switch pitch.accidental {
        case .unspecified, .natural:
            accidental = ""
        case .sharp:
            accidental = "#"
        case .flat:
            accidental = "b"
        case .doubleSharp:
            accidental = "##"
        case .doubleFlat:
            accidental = "bb"
        }

        return "\(pitch.letter.rawValue)\(accidental)\(pitch.octave)"
    }
}

nonisolated enum PracticeFeedback: Hashable {
    case neutral
    case correct(playedPitch: Pitch)
    case incorrect(playedPitch: Pitch)

    init(result: AnswerResult) {
        switch result.outcome {
        case .correct:
            self = .correct(playedPitch: result.playedPitch)
        case .incorrect:
            self = .incorrect(playedPitch: result.playedPitch)
        }
    }
}
