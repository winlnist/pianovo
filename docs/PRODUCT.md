# Product

## Working Product Identity

The combined app's working user-facing name is Pianovo, with the tagline "Practice measured. Progress earned."

Pianovo is a working brand name, not legal or trademark clearance. Keep the name centralized and easy to change until clearance is complete. Do not rename technical identifiers such as the Xcode project, targets, schemes, Swift module, bundle identifier, repository folder, or source file prefixes without a dedicated rename milestone.

Sightlink Piano is a native SwiftUI app for iPhone and iPad that helps piano learners practice reading music and playing the correct notes on a physical MIDI keyboard.

## Core Purpose

The app should reduce the gap between seeing notation and finding the correct key on the piano. It should give immediate feedback, track progress, and gradually support richer musical material.

## Current Product Experience

The current app launches into a Pianovo navigation shell with Practice selected. Practice remains the existing continuous single-staff sight-reading experience:

- The user selects Treble Reading or Bass Reading.
- The app shows a paper-like music page with measures, systems, quarter notes, and a current-event highlight.
- Exercises contain ordered reading events generated before practice begins.
- Correct MIDI input advances through the sequence.
- Incorrect MIDI input leaves the current event active.
- A new exercise is generated automatically after the final event.
- Treble Reading defaults to C4-C6.
- Bass Reading defaults to C2-C4.
- Range controls use natural-note options within C2-C6.
- Statistics are session-only and are not persisted.

The current production experience is no longer the original one-note flash-card view.

## Near-Term Direction

The user should be able to:

- Follow a data-driven twelve-week Pianovo programme once programme UI is introduced.
- Move through primary destinations for Today, Practice, Progress, Library, History, Ask My Teacher, and Settings, with unfinished areas clearly marked for later milestones.
- Choose a practice range.
- Practice treble or bass sight reading from a physical MIDI piano.
- Receive clear correctness feedback.
- Advance through a practice session.
- Review basic accuracy and progress.
- Improve generated notation readability and practice flow.

Near-term work should continue strengthening the current reading loop before expanding into imported songs.

## Platform

- Native iPhone and iPad app.
- SwiftUI application shell.
- CoreMIDI for physical MIDI piano input.
- Renderer-agnostic notation architecture.

## Long-Term Vision

Over time, Sightlink Piano should grow into an App Store-quality practice app with multiple practice activities:

- Grand-staff and two-hand practice.
- Chord reading.
- Accidentals and key signatures.
- Rhythm-aware exercises.
- Full-score rendering.
- Interactive song practice.
- MusicXML import.
- PDF or photo sheet-music import.
- Optical music recognition.
- Structured progress history.
- Personalized difficulty and review.

## Current Non-Goals

- Mixed/grand-staff continuous practice.
- Two-hand practice.
- Chords.
- Accidentals in generated practice.
- Rhythm variation, rests, ties, tuplets, or real time signatures.
- MusicXML file picker/import UI.
- Production imported-score UI.
- Interactive imported-song practice.
- PDF recognition.
- AI recognition.
- Optical music recognition.
- Persistence/history.
- Programme UI and persisted mastery decisions.
- MIDI output or recording.
- User accounts or cloud sync.

## Product Principles

- Keep practice fast and clear.
- Favor correctness and musical accuracy over visual flourish.
- Make each feature useful before making it broad.
- Keep Version 0.1 small enough to finish and test well.
- Design the foundation so later full-score and import workflows do not require rewriting the core domain.
