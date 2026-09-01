# Practice Engine

The Practice Engine owns exercise behavior. It should be independent from SwiftUI views, notation renderers, CoreMIDI, and persistence.

## Responsibilities

The Practice Engine should:

- Generate or receive prompts.
- Track the current expected answer.
- Interpret domain-level input events.
- Compare played notes or chords against expected notes or chords.
- Record correct and incorrect attempts.
- Advance when the prompt is answered correctly.
- Produce session statistics.

## Version 0.1 Practice Loop

Version 0.1 began as a simple random note-reading loop. Milestone 5.6 evolves that loop into continuous sight-reading:

1. Generate a complete `ReadingExercise` before practice begins.
2. Organize the exercise into ordered measures and ordered musical events.
3. Display the exercise as a sheet-like page through a renderer adapter.
4. Receive a played pitch from the MIDI adapter.
5. Compare the played pitch with the current expected event.
6. Record correct or incorrect.
7. Advance the current event index after a correct answer.
8. Generate a fresh exercise after the final event is answered correctly.

The practice engine should not draw notation and should not read CoreMIDI messages directly.

The Version 0.1 app UI owns session lifecycle through a thin coordinator. Changing the selected practice range or reading mode restarts the session with a new `PracticeConfiguration`, clears presentation feedback, and resets statistics. The reset control follows the same restart behavior for the currently selected mode and range. Sessions are not persisted yet.

## Reading Exercise Model

Milestone 5.6 uses a small generated-exercise model:

```text
ReadingExercise
  -> ordered ReadingMeasure values
  -> ordered ReadingEvent values
```

For this milestone:

- Treble Reading and Bass Reading are separate modes.
- Mixed clef and grand-staff continuous reading are future work.
- 4/4 is assumed.
- Each measure contains four quarter-note events.
- Each generated event currently contains one expected pitch.
- `ReadingEvent` stores expected pitches as a collection so future chord events can fit the same exercise shape.
- Accidentals, rests, ties, rhythm variation, key signatures, tuplets, and chords are intentionally excluded.

The exercise is independent from page layout. Rotation or size changes should reflow measures into systems without regenerating musical content or resetting the current event index.

## Compatibility Terminology

Some source names still reflect the earlier single-prompt loop:

- `PracticePrompt` is currently a compatibility alias to `ReadingEvent`.
- `promptsCompleted` currently means completed reading events in continuous practice.

These names may be cleaned up during a future broader practice-model refactor. They should not be renamed piecemeal while the current behavior is stable.

## Inputs

Inputs should be domain-level concepts, such as:

- Note pressed.
- Note released.
- Chord candidate changed.
- Answer submitted.

The MIDI adapter can produce these inputs from CoreMIDI note-on and note-off messages.

## Matching

For Version 0.1, matching can be exact pitch matching:

- Expected single pitch equals played single pitch.
- A correct answer advances to the next event.
- Incorrect attempts increment the incorrect count and keep the current event active.

Version 0.1 exercise generation should prefer natural notes from the configured pitch range so prompts remain suitable for the initial renderer. Treble and bass modes intersect the configured range with the mode-supported range before generation. If a configured range contains no natural notes in the selected mode, generation may fall back to compatible chromatic pitches or the mode default rather than failing. When more than one eligible pitch exists, generation avoids immediate repeated pitches where practical.

Future matching should support:

- Chords.
- Enharmonic equivalence rules.
- Timing windows.
- Rhythm accuracy.
- Partial credit.
- Song-event matching by stable event identifier.

## Session Statistics

Basic session statistics should be separate from the score model.

Version 0.1 statistics can include:

- Correct answers.
- Incorrect attempts.
- Total attempts.
- Accuracy percentage.
- Current streak.
- Events completed.

Every submitted note-on played pitch counts as one attempt. Accuracy is `correctAnswers / totalAttempts`, reported as a percentage and treated as `0` when there are no attempts.

Future statistics can include:

- Accuracy by pitch.
- Accuracy by clef.
- Accuracy by range.
- Accuracy by song.
- Accuracy by score event identifier.
- Time spent.
- Review recommendations.

## Test Priorities

- Correct pitch advances the current event.
- Incorrect pitch does not advance the current event.
- Correct and incorrect counts update accurately.
- Accuracy calculations are stable.
- Exercise generation respects configured range.
- Matching logic remains independent from rendering and MIDI.
