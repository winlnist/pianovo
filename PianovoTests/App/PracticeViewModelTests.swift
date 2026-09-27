import CoreGraphics
import Testing
@testable import Pianovo

@MainActor
struct PracticeViewModelTests {
    @Test func midiNotePressRoutesToPracticeSession() {
        let viewModel = PracticeViewModel()
        let expectedPitch = viewModel.currentPrompt.expectedPitch
        let event = MIDIInputEvent(
            kind: .notePressed,
            pitch: expectedPitch,
            midiNoteNumber: expectedPitch.midiNoteNumber,
            velocity: 90,
            channel: 1
        )

        viewModel.submit(event)

        #expect(viewModel.statistics.correctAnswers == 1)
        #expect(viewModel.statistics.totalAttempts == 1)
        #expect(viewModel.statistics.promptsCompleted == 1)
        #expect(viewModel.feedback == .correct(playedPitch: expectedPitch))
    }

    @Test func midiNoteReleaseDoesNotCountAsAnswer() {
        let viewModel = PracticeViewModel()
        let promptBeforeRelease = viewModel.currentPrompt
        let event = MIDIInputEvent(
            kind: .noteReleased,
            pitch: promptBeforeRelease.expectedPitch,
            midiNoteNumber: promptBeforeRelease.expectedPitch.midiNoteNumber,
            velocity: 0,
            channel: 1
        )

        viewModel.submit(event)

        #expect(viewModel.currentPrompt == promptBeforeRelease)
        #expect(viewModel.statistics.totalAttempts == 0)
        #expect(viewModel.feedback == .neutral)
    }

    @Test func incorrectAnswerMapsToIncorrectPresentationState() {
        let viewModel = PracticeViewModel()
        let wrongPitch = pitchDifferentFrom(viewModel.currentPrompt.expectedPitch)

        viewModel.submit(.notePressed(wrongPitch))

        #expect(viewModel.statistics.incorrectAttempts == 1)
        #expect(viewModel.statistics.totalAttempts == 1)
        #expect(viewModel.statistics.currentStreak == 0)
        #expect(viewModel.feedback == .incorrect(playedPitch: wrongPitch))
    }

    @Test func rangeChangesProduceNewValidConfigurationAndRestartSession() {
        let viewModel = PracticeViewModel()

        viewModel.submit(.notePressed(pitchDifferentFrom(viewModel.currentPrompt.expectedPitch)))
        viewModel.updateLowerPitch(Pitch(.c, octave: 4))
        viewModel.updateUpperPitch(Pitch(.g, octave: 4))

        #expect(viewModel.session.configuration.pitchRange.lowerBound == Pitch(.c, octave: 4))
        #expect(viewModel.session.configuration.pitchRange.upperBound == Pitch(.g, octave: 4))
        #expect(viewModel.session.configuration.pitchRange.contains(viewModel.currentPrompt.expectedPitch))
        #expect(viewModel.statistics.totalAttempts == 0)
        #expect(viewModel.feedback == .neutral)
    }

    @Test func reversedRangeSelectionIsCorrectedToStayValid() {
        let viewModel = PracticeViewModel()

        viewModel.updateLowerPitch(Pitch(.c, octave: 6))
        viewModel.updateUpperPitch(Pitch(.c, octave: 2))

        #expect(viewModel.lowerPitch == Pitch(.c, octave: 4))
        #expect(viewModel.upperPitch == Pitch(.c, octave: 4))
        #expect(viewModel.session.configuration.pitchRange.lowerBound == Pitch(.c, octave: 4))
        #expect(viewModel.session.configuration.pitchRange.upperBound == Pitch(.c, octave: 4))
    }

    @Test func trebleToBassModeChangeUsesMultiPitchBassRangeWhenOldRangeOnlyOverlapsAtC4() {
        let viewModel = PracticeViewModel()

        viewModel.updateLowerPitch(Pitch(.c, octave: 5))
        viewModel.updateUpperPitch(Pitch(.c, octave: 6))
        viewModel.updateMode(.bassReading)

        #expect(viewModel.mode == .bassReading)
        #expect(viewModel.lowerPitch == Pitch(.c, octave: 2))
        #expect(viewModel.upperPitch == Pitch(.c, octave: 4))
        #expect(viewModel.session.configuration.mode == .bassReading)
        #expect(viewModel.session.configuration.eligiblePitches.count > 1)
        #expect(viewModel.exercise.mode == .bassReading)
        #expect(viewModel.exercise.events.allSatisfy { viewModel.session.configuration.pitchRange.contains($0.expectedPitch) })
        #expect(Set(viewModel.exercise.events.map(\.expectedPitch)).count > 1)
        #expect(viewModel.statistics.totalAttempts == 0)
    }

    @Test func bassToTrebleModeChangeUsesMultiPitchTrebleRangeWhenOldRangeOnlyOverlapsAtC4() {
        let viewModel = PracticeViewModel(initialMode: .bassReading)

        viewModel.updateLowerPitch(Pitch(.c, octave: 2))
        viewModel.updateUpperPitch(Pitch(.c, octave: 3))
        viewModel.updateMode(.trebleReading)

        #expect(viewModel.mode == .trebleReading)
        #expect(viewModel.lowerPitch == Pitch(.c, octave: 4))
        #expect(viewModel.upperPitch == Pitch(.c, octave: 6))
        #expect(viewModel.session.configuration.mode == .trebleReading)
        #expect(viewModel.session.configuration.eligiblePitches.count > 1)
        #expect(viewModel.exercise.mode == .trebleReading)
        #expect(viewModel.exercise.events.allSatisfy { viewModel.session.configuration.pitchRange.contains($0.expectedPitch) })
        #expect(Set(viewModel.exercise.events.map(\.expectedPitch)).count > 1)
        #expect(viewModel.statistics.totalAttempts == 0)
    }

    @Test func modeSwitchRegeneratesExerciseButLayoutReflowDoesNot() {
        let viewModel = PracticeViewModel()
        let originalExercise = viewModel.exercise
        let policy = SightReadingLayoutPolicy()

        let portraitEvents = policy.systems(for: viewModel.exercise, availableWidth: 650).flatMap(\.measures).flatMap(\.events)
        let landscapeEvents = policy.systems(for: viewModel.exercise, availableWidth: 920).flatMap(\.measures).flatMap(\.events)

        #expect(portraitEvents == viewModel.exercise.events)
        #expect(landscapeEvents == viewModel.exercise.events)

        viewModel.updateMode(.bassReading)

        #expect(viewModel.exercise != originalExercise)
        #expect(viewModel.exercise.mode == .bassReading)
        #expect(viewModel.currentEventIndex == 0)
    }

    @Test func sessionResetClearsStatisticsAndFeedback() {
        let viewModel = PracticeViewModel()
        viewModel.submit(.notePressed(pitchDifferentFrom(viewModel.currentPrompt.expectedPitch)))

        viewModel.resetSession()

        #expect(viewModel.statistics.correctAnswers == 0)
        #expect(viewModel.statistics.incorrectAttempts == 0)
        #expect(viewModel.statistics.totalAttempts == 0)
        #expect(viewModel.statistics.promptsCompleted == 0)
        #expect(viewModel.statistics.currentStreak == 0)
        #expect(viewModel.feedback == .neutral)
    }

    @Test func currentPromptRemainsValidWithoutMIDIEvents() {
        let viewModel = PracticeViewModel()

        #expect(viewModel.session.configuration.pitchRange.contains(viewModel.currentPrompt.expectedPitch))
        #expect(PracticeMode.trebleReading.supportedPitchRange.contains(viewModel.currentPrompt.expectedPitch))
    }

    private func pitchDifferentFrom(_ pitch: Pitch) -> Pitch {
        pitch == Pitch(.c, octave: 4) ? Pitch(.d, octave: 4) : Pitch(.c, octave: 4)
    }
}
