# Roadmap

The roadmap keeps Pianovo small at first while preserving a path toward full interactive score practice.

Milestones through 6F.5 provide Today programme start/saved-day presentation, assigned generated sight-reading sessions, and explicit self-reported completion/undo. Practice remains the working MIDI reading experience. The next direction is reusable content and editable learner programmes: 6F.6 records the design, followed by the private local exercise Library in 6F.7. Programme advancement, programme templates/editing, and remote services remain unimplemented. Exercise templates are completed in 6F.8; template navigation and exercise creation from a template were manually validated.

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
- At this milestone, preserve the earlier technical identifiers; they are renamed separately in the later Technical Project Rename milestone.
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

### Technical Project Rename - Completed

- Rename the former Sightlink Piano project, targets, scheme, modules, bundle identifiers, and source/test folders to Pianovo/PianovoTests.
- Share the Pianovo scheme for development and CI while preserving implementation, resources, stable domain identifiers, and the Verovio package configuration.
- Keep the Milestone 6C technical-name preservation above as historical scope; Today UI remains deferred to 6F.3.

### 6F.3 Today Screen and Start Programme Flow - Completed

- Replace the Today placeholder with a native SwiftUI screen driven by the existing `TodayViewModel` state.
- Keep first launch explicit: the learner chooses when to start the programme.
- Create active progress at Week 1, Day 1 without creating fictional sessions, completions, attempts, or mastery decisions.
- Present morning, evening, and recovery work without advancing programme position from the calendar date.
- Show Beyer Op. 101 No. 63 as one assignment with required Seconda and Prima components.
- Keep unavailable reference documents visible but honestly marked unavailable.
- Open in Today while preserving direct access to the unchanged working Practice screen.
- Keep the screen-owned view model stable, load once on entry, and use explicit retry for fresh reads.
- Guard overlapping starts and loads, re-read before saving, preserve existing positions, and use injected temporal context.
- Add deterministic start/lifecycle tests and in-memory previews for first launch, practice, recovery, material availability, and persistence failure.
- Defer session lifecycle, completion actions, PDF presentation, automatic mastery evaluation, teacher features, and cloud sync.

### 6F.4 Assigned Sight-Reading Session Lifecycle - Completed

- Route only the supported generated sight-reading source from Today to preparation and the existing MIDI Practice surface.
- Preserve the complete stable programme/week/day/block/assignment/source context without parsing IDs.
- Configure Treble/Bass and natural-note range before explicit Start Session; lock configuration/reset during the session.
- Keep active sessions in memory and save one immutable `.stopped` record only on End & Save.
- Show actual frozen statistics immediately, explicitly without persisting numeric results.
- Serialize start/finish/retry, retain exact failed records, and reconcile ambiguous duplicates against durable history.
- Suspend input during inactivity; freeze on background and offer save/discard on return without counting background time.
- Use the unchanged V1 schema and insert-only session semantics, with isolated insertion rollback and separate-context verification.
- Preserve standalone Practice and keep unsupported assignments informational.
- Defer force-quit recovery, assignment completion, mastery, programme advancement, generic sessions, PDFs, raw MIDI, analysis, History/Progress UI, teacher/API/cloud work, and 6F.5.

### 6F.5 Self-Reported Assignment Completion - Completed

- Offer Mark complete and Undo completion for every assignment in the saved current day, including outside-app work and recovery/reflection assignments.
- Label completion as the learner's report, distinct from mastery and from saving a session.
- Require confirmation of both Seconda and Prima before completing Beyer No. 63 as one assignment; defer component-level records.
- Validate current programme/version/week/day and assignment/source context against a fresh progress read.
- Persist only the existing assignment completion record; undo returns it to Not started with no completion time and preserves notes/history/mastery.
- Serialize actions, retain intent/timestamps for retry, verify durable status before changing the display, and provide an explicit refresh.
- Isolate failed SwiftData completion upserts from unrelated pending changes without schema or protocol changes.
- Verify completion/undo restoration, repeated taps, required parts, stale positions, save/read failures, ambiguous saves, and the existing Practice flow.
- Defer programme advancement and its mastery policy, PDFs, analysis, History/Progress UI, teacher/API/cloud work, and force-quit recovery.

### 6F.6 Reusable Content and Programme Design - Design Recorded

- Define exercise templates, exercises/revisions, programme templates, independent learner programmes, and scheduled assignments.
- Support human-teacher and independent/AI-assisted learning with the same content model.
- Design identity, ownership, attribution, versions, explicit updates, and history preservation before local authoring.
- Treat Today as a projection of the current saved learner-programme day; retain the current seed and identifiers until a tested migration exists.
- Plan a real local database plus future hosted accounts/content/API/sync and separate student-data access boundaries.
- Record future notes, starter/paid access, and community/free/paid content without selecting commercial terms or providers.
- See [Reusable Content, Programmes, and Sharing](CONTENT_AND_PROGRAMMES.md) for the design baseline, first-implementation acceptance criteria, and open later decisions.
- Documentation only: no Swift, schema, project, dependency, runtime, or backend changes.

### 6F.7 Local Exercise Library - Completed

- Introduce framework-independent authored exercise identity, saved revisions, origin metadata, and validation.
- Use a separately named/versioned Library SwiftData store behind its own repository; preserve the progress V1 schema/store unchanged.
- Replace the Library placeholder with private list/detail/create/edit/archive/restore workflows for title, category, instructions, and learning purpose.
- Preserve referenced revisions and existing progress/history; make failures explicit and retry safe.
- Keep authored guidance honest: free-text exercises are not automatically playable or MIDI-assessable, and linked material does not imply document access.
- Verify restoration, stable exercise/revision identity, validation, failures, archive behaviour, and unchanged Today/Practice functionality.
- Defer templates, programme scheduling/activation, accounts, sharing, AI, document import, and payments.

### 6F.8 Exercise Templates - Completed

- Create/edit reusable exercise patterns with explicit defaults and validated configuration.
- Instantiate independent exercises with origin/template revision retained; template edits do not rewrite existing exercises.
- Add starter patterns without claiming unsupported notation generation or assessment.
- Provide private template list/detail/create/edit/archive/restore and an editable Create exercise flow.
- Pin typed template origin per independent exercise; preserve provenance through exercise edits.
- Migrate Library V1 to V2 with real legacy-store tests; leave the progress/history V1 store unchanged.
- Keep defaults as editable text, not automatic score generation or a variable-expression language.
- Defer programme templates/editor, Today scheduling, accounts, backend sharing, payments, and AI.

### 6F.9 Programme Templates and Editor - Planned

- Arrange pinned exercise revisions into weeks, ordered days, and practice sections with contextual goals/durations.
- Support configurable programme length and starter policies without a global twelve-week restriction.
- Save/copy template revisions and validate references; do not rewrite active learner plans.

### 6F.10 Individual Learner Programmes and Today Integration - Planned

- Instantiate independent plans with unique assignment-occurrence IDs and preserved template/creator origin.
- Specify and test migration from legacy definition-based progress before editable/multiple programme instances.
- Adapt personal plans explicitly and preserve historical revisions; project their current assignments into Today.
- Define next-day, unfinished-work, recovery/week-transition, and final-day behaviour separately from mastery and Beyer sequencing.
- Adopt the existing seed as starter content only through an explicit compatibility path.

### 6F.11 Local History and Learner Notes - Planned

- Expose real saved session context/times and assignment status without inventing persisted numeric statistics.
- Add private learner reflections/notes with explicit context; keep progress assessment distinct from self-report.
- Define audiences for teacher feedback, private lesson notes, and shared lesson notes before later cross-account sharing.

### 6F.12 Hosted Accounts, Synchronisation, and Teacher Collaboration - Planned

- Select a hosted database/API and authentication approach against ownership, privacy, offline, and operational requirements.
- Implement accounts, accepted teacher/student relationships, and server-enforced per-resource permissions.
- Publish assignments/plan updates with explicit acknowledgement; synchronise authorised content, progress, and notes.
- Verify idempotency, conflicts, account isolation, revocation/offline policy, and preserved local practice.

### 6F.13 AI Coaching and Assisted Authoring - Planned

- Support independent learner coaching and teacher/learner exercise/programme draft generation using the shared model.
- Connect a backend API with validated outputs, provenance, explicit acceptance, and access/cost controls.
- Use only available and authorised evidence; distinguish measurements, self-reports, and missing assessment capabilities.
- This can follow the required backend/access foundations without waiting for every teacher-collaboration feature.

### 6F.14 Community Sharing and Creator Rewards - Future

- Discover/publish free or paid exercises and both kinds of templates with attribution and revision history.
- Define acquisition, personal/teaching use, adaptation/redistribution permissions, creator compensation, moderation, and contact policies.
- Keep content purchases separate from teacher relationships and access to learner data.
- Decide starter/free access, paid continuation, AI access, and purchase rules before implementation; no pricing or entitlement promises yet.

These are staged directions, not delivery dates or permission to implement all stages at once. Each implementation should use a focused scope and explicit acceptance criteria. The longer-term rendering, analysis, progress, and release tracks below remain separate work.

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

## 9. Progress, History, and Adaptive Coaching UI

- Connect the working Practice session to the existing local progress/history repositories.
- Present persisted session summaries, assignment completion, reflections, and mastery decisions.
- Track accuracy by pitch, range, clef, song, and stable event identifier.
- Add adaptive review and sequencing on top of recorded evidence.
- Expose learner progress and teacher planning workflows.
- Keep local persistence authoritative first; evaluate accounts and sync only after the local workflow is useful.

## 10. App Store Readiness

- Polish accessibility, onboarding, and error states.
- Harden MIDI handling.
- Improve iPhone and iPad layouts.
- Add privacy documentation.
- Add app icons, metadata, screenshots, and release checks.
- Validate performance and stability.
