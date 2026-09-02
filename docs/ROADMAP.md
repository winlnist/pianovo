# Roadmap

The roadmap keeps Sightlink Piano small at first while preserving a path toward full interactive score practice.

## 0. Project Foundation - Completed

- Establish documentation and repository guidance.
- Record architectural boundaries.
- Keep the initial SwiftUI app behavior unchanged.

## 1. Music Domain - Completed

- Define pitch, octave, note names, accidentals, and MIDI note number conversion.
- Define pitch ranges, initially supporting C2-C6 while leaving room for the full piano range.
- Define clefs, grand staff assignment, staff positions, and ledger-line calculations.
- Define stable identifiers for musical events.
- Add unit tests for domain behavior.

## 2. Basic Staff Renderer - Completed

- Build a lightweight native SwiftUI/Core Graphics renderer for simple drills.
- Render treble and bass clefs on a grand staff.
- Render notes across the configured range.
- Render ledger lines correctly.
- Prepare extension points for accidentals, chords, rhythm, and full-score rendering.

## 3. Practice Engine - Completed

- Generate random note-reading prompts from a configurable range.
- Track current expected answer.
- Match played note input against expected prompt.
- Advance after a correct answer.
- Count correct and incorrect attempts.
- Keep practice state independent from SwiftUI rendering.

## 4. CoreMIDI Integration - Completed

- Detect available MIDI devices.
- Receive note-on and note-off events.
- Convert MIDI events into domain-level input.
- Route input into the practice engine.
- Handle device connection and disconnection states.

## 5. Practice Session UI and Statistics - Completed

- Build the main practice screen.
- Provide range controls.
- Show MIDI connection state.
- Display correctness feedback.
- Show basic session statistics.
- Support iPhone and iPad layouts.

### 5.5 Notation and UI Polish - Completed

- Bundle Bravura as a local SMuFL-compatible notation font.
- Use SMuFL treble and bass clefs through renderer-specific glyph helpers.
- Keep notation font details out of the Music Domain.
- Improve staff proportions, clef alignment, ledger line readability, iPad/iPhone layout, dark-mode behavior, and accessibility.
- Keep production MIDI status simple while preserving `MIDIDebugView` for troubleshooting.

### 5.6 Continuous Sight-Reading Practice - Completed

- Generate a complete reading exercise before practice begins.
- Represent exercises as ordered measures and ordered events.
- Keep exercise structure separate from responsive page/system layout.
- Support Treble Reading and Bass Reading as separate modes.
- Render a paper-like sheet with systems, measures, barlines, quarter notes, stems, ledger lines, and a current-event cursor.
- Use an auto-hiding HUD so controls and statistics do not resize or reflow the music page.
- Preserve MIDI note-on/note-off semantics and existing statistics behavior.

### 5.6.1 State and Layout Refinement - Completed

- Fix mode-switch range collapse so Treble/Bass changes do not produce C-only exercises unless the configured range truly contains one eligible pitch.
- Balance measure grouping across systems to avoid sparse final systems when width allows redistribution.
- Modestly reduce clef visual dominance and tighten clef-to-first-measure spacing.
- Preserve exercise identity, event order, current event, statistics, mode, and selected range during layout reflow.

### 5.7 Full Score Domain Design - Completed

- Add framework-independent score domain types for future imported songs and full-score practice.
- Represent scores, parts, staves, measures, voices, notes, chords, rests, exact durations, musical positions, time signatures, key signatures, clef changes, ties, and stable score-event identifiers.
- Keep the existing `ReadingExercise`, `ReadingEvent`, `PracticeSession`, and production continuous sight-reading UI unchanged.
- Document the boundary between the lightweight generated-practice model and the future full-score model.
- Defer MusicXML parsing, Verovio integration, score UI, imported-song practice, rhythm grading, playback, persistence, and PDF/photo recognition to later milestones.

## 6. MusicXML and Full-Score Rendering

### 6A MusicXML Import Foundation - Completed

- Add a Foundation-based MusicXML adapter outside the Music Domain.
- Parse a small `score-partwise` subset into the Full Score Domain.
- Support part names, measures, divisions, time signatures, key signatures, treble/bass clefs, staff and voice assignment, pitched notes, rests, simple chords, accidentals, ties, MusicXML `<backup>`/`<forward>` cursor movement, and deterministic imported event IDs.
- Preserve the existing generated-practice model and production practice UI.
- Defer MusicXML file UI, broader MusicXML coverage, Verovio, full-score rendering, and imported-song practice.

### 6B Verovio Full-Score Rendering - Completed

- Add Verovio through Swift Package Manager as the full-score rendering engine.
- Keep Verovio isolated in a `Rendering/FullScore` adapter layer.
- Render existing MusicXML fixtures to SVG.
- Provide a development-facing `FullScoreDebugView` for fixture rendering inspection without replacing `PracticeScreen`.
- Prove at least one fixture succeeds through both paths: MusicXML import into the Score Domain and MusicXML rendering through Verovio.
- Keep native drill/continuous-practice rendering separate from Verovio.
- Defer imported-song practice, event highlighting inside Verovio output, file picker UI, broader MusicXML coverage, PDF/photo import, OMR, playback, and persistence.

### 6C Pianovo Identity and Navigation Shell - Completed

- Add Pianovo as the working user-facing product name and centralize the tagline "Practice measured. Progress earned."
- Preserve all technical identifiers, including the Xcode project, targets, schemes, Swift module, bundle identifiers, folders, and source file prefixes.
- Introduce primary app destinations for Today, Practice, Progress, Library, History, Ask My Teacher, and Settings.
- Keep Practice wired to the existing production `PracticeScreen`.
- Mark unfinished destinations as coming in a later milestone.
- Do not add Beyer PDFs, supporting PDFs, audio materials, persistence, programme data, coach services, or technical rename work.

### 6D Programme and Mastery Domain - Completed

- Add framework-independent programme types using British spelling: `PracticeProgramme`, `ProgrammeWeek`, `PracticeDay`, `PracticeBlock`, `PracticeAssignment`, `ExerciseSource`, `MasteryRule`, and `MasteryState`.
- Keep assignments data-driven through stable `ExerciseSourceID` references rather than SwiftUI hard-coding or direct score-event/PDF/MusicXML/Verovio mappings.
- Add structured validation issues for general programme structure, including unique IDs, valid ordering, positive durations, required fields, source references, and mastery-rule references.
- Keep Pianovo twelve-week policy validation separate from reusable domain validation.
- Seed the twelve-week Pianovo structure with six practice days and one recovery/reflection day per week, typical 45-minute morning and evening practice sessions, and minimal source metadata.
- Begin Beyer at Op. 101 No. 63 in Week 1; use an adaptive current-Beyer source for later weeks instead of preassigning later exercise numbers.
- Model mastery learning states without treating manual override as a mastery state.
- Defer persistence, progress records, mastery evaluation history, MIDI analysis, score-source mappings, PDFs, audio, coach functionality, and SwiftUI integration.

### 6E Local Persistence and History Foundation - Completed

- Add Foundation-only progress records and repository protocols for active programme progress, assignment completion state, practice sessions, performance attempts, student reflections, and mastery decisions.
- Keep Programme Domain and Music Domain independent from SwiftData and other persistence frameworks.
- Add a SwiftData V1 schema, migration-plan scaffold, and local repository adapter inside `Persistence/SwiftData`.
- Store programme ID/version and stable week/day/block/assignment/source references rather than duplicating immutable seed programme content.
- Store absolute timestamps, time-zone identifiers, supported calendar identifiers, and creation-time local-day keys for temporal records.
- Define duplicate-ID write semantics, structured validation failures, reset behaviour, cascade session deletion, and explicit all-data deletion.
- Add deterministic in-memory repository tests and SwiftData in-memory `ModelContainer` tests.
- Defer SwiftUI history screens, app-root persistence wiring, automatic mastery evaluation, MIDI/audio capture, score assessment, coach/API integration, cloud sync, export UI, and 6F work.

### 6F.1 Reference Material Catalogue and Source Resolution - Completed

- Add a Foundation-only reference-material catalogue for all inspected local reference PDFs/audio without copying those files into source control or the app bundle.
- Keep reference material identity logical and stable through `ReferenceMaterialID`, document descriptors, and component IDs.
- Keep `ExerciseSourceID` to `ReferenceMaterialID` mapping inside a resolver boundary rather than Programme Domain.
- Represent document availability separately from catalogue metadata, document access, programme assignment, and PDF presentation.
- Add a default deterministic availability provider that reports known materials as unavailable until a later document-access adapter exists.
- Model Beyer Op. 101 No. 63 as one logical exercise with distinct required Seconda and Prima components for the inspected 88-page Edition Peters scan.
- Distinguish zero-based PDFKit page indices from printed page labels, and defer exact crop rectangles to visual verification.
- Keep unverified rights status explicit as unknown.
- Defer Today UI, Practice UI changes, PDFKit display, file importing, security-scoped bookmarks, document copying, bundled resources, persistence changes, MIDI/audio analysis, coach/API work, and 6F.2.

### 6F.2 Today View Model and Dependency Composition - Completed

- Add a Today-facing presentation state and `TodayViewModel` without implementing the Today screen UI.
- Compose the Pianovo seed programme, persisted active progress, assignment completions, latest mastery decisions, reference-material resolution, document availability, and deterministic temporal context.
- Keep first launch as an explicit programme-not-started state; do not create active progress or advance week/day from calendar date.
- Add production dependency composition that retains the SwiftData `ModelContainer` and exposes persistence-unavailable state if bootstrap fails.
- Add a narrow latest-mastery repository query with deterministic assignment/source grouping and stable-ID tie-breaking for equal timestamps.
- Keep time-of-day presentational only: morning/evening may be suggested, but both remain visible and no persistence is written.
- Present Beyer Op. 101 No. 63 with distinct required Prima and Seconda components for Today state while deferring component-level progress/mastery.
- Defer Today UI, Start Programme action, session lifecycle, PDF display/import, component-level completion, MIDI/audio analysis, coach/API, cloud sync, and 6F.3.

## 7. Interactive Song Practice

- Present imported songs as interactive scores.
- Associate practice prompts with stable score event identifiers.
- Support event-by-event or measure-by-measure practice.
- Track per-event correctness and progress.

## 8. PDF/Photo Optical Music Recognition Pipeline

- Define the pipeline from image input to structured notation.
- Explore optical music recognition options.
- Convert recognized notation into MusicXML or direct domain models.
- Add verification and correction UX before practice.

## 9. Progress, History, and Persistence

- Persist session summaries.
- Track accuracy by pitch, range, clef, song, and event identifier.
- Separate progress records from score definitions.
- Add local persistence first; evaluate sync later.

## 10. App Store Readiness

- Polish accessibility, onboarding, and error states.
- Harden MIDI handling.
- Improve iPhone and iPad layouts.
- Add privacy documentation.
- Add app icons, metadata, screenshots, and release checks.
- Validate performance and stability.
