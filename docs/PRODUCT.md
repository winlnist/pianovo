# Product

## Identity

Pianovo is a native iPhone and iPad piano-practice app with the tagline “Practice measured. Progress earned.” The Xcode project, app target, shared scheme, module, source folder, and bundle identifiers now use the Pianovo name. The name has not undergone legal or trademark clearance.

## Problem and motivation

Piano learners commonly work across paper methods, scales, teacher notes, and disconnected practice tools. Those materials show what to play, but they do not create a measurable practice loop or make the next task clear.

Pianovo began as a personal response to that gap. The immediate goal is to reduce the distance between seeing notation and finding the correct piano key. The broader goal is to help a learner organise practice independently while leaving room for a teacher to review progress and assign future work.

The product direction joins three ideas:

- **Practise:** play generated or assigned material with immediate MIDI feedback.
- **Plan:** follow a structured programme that progresses through demonstrated mastery.
- **Collaborate:** eventually allow a teacher to review evidence and adjust a student’s plan.

## Intended users

### Learner

A piano learner who wants clear daily work, immediate feedback, and evidence of progress. The initial programme is grounded in the creator’s current context: improving already-familiar scales and arpeggios and continuing the Beyer method from Op. 101 No. 63, including both Seconda and Prima where applicable.

### Teacher — future workflow

A teacher who can eventually review a student’s practice history, assign or adjust upcoming material, and answer questions. Teacher accounts, remote planning, chat, and cloud sync are not implemented in the current app.

## Current user-facing experience

The app launches into Today, where learners explicitly start the programme at Week 1 Day 1 and view the saved day. Morning, Evening, recovery/reflection, saved assignment/mastery status, and honest material availability are presented without automatic day advancement. Practice is a working continuous single-staff sight-reading experience:

- Choose Treble Reading or Bass Reading.
- Read a generated 64-note exercise arranged into measures and responsive systems.
- Adjust the natural-note range within C4-C6 for treble or C2-C4 for bass.
- Play on a physical MIDI piano.
- Advance after a correct note; remain on the current note after an incorrect attempt.
- Receive a new exercise after completing the current one.
- Review session-only correct, wrong, attempt, accuracy, streak, and completion values.

The paper-like score remains stable while an auto-hiding HUD exposes MIDI status and controls. Progress, Library, History, Ask My Teacher, and Settings currently show “coming later” states.

## Implemented but not yet exposed as complete workflows

- A twelve-week programme and mastery domain beginning at Beyer Op. 101 No. 63.
- Local SwiftData models and repositories for active progress, completions, sessions, attempts, reflections, and mastery decisions.
- Today presentation state that can combine programme position, persisted progress, mastery, and reference-material availability.
- A logical catalogue for Beyer and supporting practice material; the source documents are not bundled or openable in the app.
- A limited MusicXML importer and a development-only Verovio fixture renderer.

Milestone 6F.4 connects only the generated sight-reading assignment to an explicit session flow: preparation, Start Session, MIDI Practice, End & Save, immediate summary, and return to Today. Preparation shows the assignment goal and planned duration and lets the learner choose Treble/Bass and a natural-note range. Configuration and reset are locked while the assigned session is active. Other assignments remain informational; Beyer is never substituted with random notation.

End & Save records one stopped session with its stable programme/week/day/block/assignment/source context and timestamps. Numeric statistics are temporary feedback in the immediate summary, not saved history. Ending does not mark an assignment complete, evaluate mastery, create attempts/reflections, or advance programme position. Standalone Practice remains available without persistence.

Temporary inactivity suspends MIDI input. Backgrounding freezes the session at the observed time; returning offers save or discard, not resume. Discard performs no write. Force-quit recovery is not supported: unsaved sessions may be lost. No duration is invented after termination.

The remaining foundations must not be presented as working Progress, History, document-library, or imported-song experiences.

## Near-term product direction

- Extend assigned practice only when its source can be presented honestly.
- Add explicit assignment-completion and progress workflows separately from session recording.
- Present user-imported or legally distributable reference material.
- Add score-aligned MIDI timing and correctness analysis.
- Expose progress in a way that is useful to both learner and teacher.

## Longer-term vision

- Grand-staff, two-hand, chord, accidental, key-signature, and rhythm-aware practice.
- Interactive MusicXML scores and full-song practice.
- PDF/photo import with optical music recognition and a verification workflow.
- Tempo and note-quality feedback from MIDI first, with audio analysis considered separately.
- Structured learner/teacher collaboration, accounts, and optional sync.

## Product principles

- Make the next practice action clear.
- Measure performance without interrupting musical flow.
- Progress from evidence of mastery, not simply elapsed calendar time.
- Keep teacher involvement possible without making self-directed practice dependent on it.
- Distinguish working UI, implemented foundations, and planned functionality.
- Prefer correct musical behaviour over visual novelty.
- Keep personal practice data local-first until sync has a justified product need.
- Do not distribute copyrighted reference material without confirmed rights.

## Current limitations and non-goals

- No mixed/grand-staff, two-hand, chord, accidental, or rhythm-varying generated practice.
- No persisted numeric statistics; assigned sight-reading saves session context and times only.
- No functional Progress, Library, History, teacher, or settings workflows.
- No assignment-completion controls, automatic mastery, generic guided sessions, or durable active-session recovery.
- No production MusicXML file picker or imported-song practice.
- No PDF/photo import, optical music recognition, or score correction UI.
- No MIDI recording timeline, tempo assessment, audio analysis, or playback.
- No accounts, teacher portal, chat service, cloud sync, or API-key-backed coach.
