# Product

## Identity

Pianovo is a native iPhone and iPad piano-practice app with the tagline “Practice measured. Progress earned.” The Xcode project, app target, shared scheme, module, source folder, and bundle identifiers now use the Pianovo name. The name has not undergone legal or trademark clearance.

## Problem and motivation

Piano learners commonly work across paper methods, scales, teacher notes, and disconnected practice tools. Those materials show what to play, but they do not create a measurable practice loop or make the next task clear.

Pianovo began as a personal response to that gap. The immediate goal is to reduce the distance between seeing notation and finding the correct piano key. The broader goal is to help a learner organise practice independently while leaving room for a teacher to review progress and assign future work.

The product direction joins three ideas:

- **Practise:** play generated or assigned material with immediate MIDI feedback.
- **Plan:** create or follow an individual programme built from reusable exercises and templates, with progression distinct from self-reported completion.
- **Collaborate:** eventually let teachers assign work, review evidence, take lesson notes, and adjust a student’s plan; support independent learning with AI coaching as a separate path.

## Intended users

### Learner

A piano learner who wants clear daily work, immediate feedback, and evidence of progress. The initial programme is grounded in the creator’s current context: improving already-familiar scales and arpeggios and continuing the Beyer method from Op. 101 No. 63, including both Seconda and Prima where applicable.

### Teacher — future workflow

A teacher who creates exercises and both exercise/programme templates, adapts individual student plans, publishes work to student iPads, reviews authorised practice history, and records lesson feedback/notes. Teacher accounts, remote planning, notes UI, chat, and cloud sync are not implemented in the current app.

### Independent learner — future workflow

A learner who begins with starter exercises and a starter programme template, adapts their own plan, and can use AI coaching for explanation, exercise/programme drafting, and proposed adjustments. A human teacher is optional. AI must distinguish measured practice evidence from learner reports and cannot imply assessments the app does not support.

### Creator/community participant — future workflow

Teachers and other permitted creators may eventually publish free or paid teaching material. Teachers can acquire and adapt templates under their permissions; learners can acquire programmes for independent study and may enquire about lessons. Creator rewards, community publishing, purchases, and contact features are not implemented. Pricing and paid-access rules remain undecided.

## Agreed content and programme direction — planned

The shared foundation is exercise templates, authored exercises, programme templates, individual learner programmes, and scheduled assignments. An exercise is reusable content; an assignment places a specific exercise revision into a learner's week/day/section with a goal and planned duration. Today displays that saved individual plan. Completion belongs to the assignment, not the shared exercise.

Templates produce independent editable content/plans while retaining origin and attribution. Updates must be explicit and preserve existing practice history. The twelve-week programme is a starter default, not a global limit; later templates can describe longer or differently structured programmes.

The first implementation is a durable local exercise Library. Its identity, version, ownership, and repository boundaries must support a later hosted database/API, offline synchronisation, accounts, and authorised teacher/student sharing. AI-assisted content uses the same model and starts as a reviewable draft. Marketplace and entitlement handling build on those foundations later.

See [Reusable Content, Programmes, and Sharing](CONTENT_AND_PROGRAMMES.md) for the design baseline, compatibility constraints, and phased scope. None of these planned editors or services is a shipped workflow.

## Current user-facing experience

The app launches into Today, where learners explicitly start the programme at Week 1 Day 1 and view the saved day. Morning, Evening, recovery/reflection, saved assignment/mastery status, and honest material availability are presented without automatic day advancement. Practice is a working continuous single-staff sight-reading experience:

- Choose Treble Reading or Bass Reading.
- Read a generated 64-note exercise arranged into measures and responsive systems.
- Adjust the natural-note range within C4-C6 for treble or C2-C4 for bass.
- Play on a physical MIDI piano.
- Advance after a correct note; remain on the current note after an incorrect attempt.
- Receive a new exercise after completing the current one.
- Review session-only correct, wrong, attempt, accuracy, streak, and completion values.

The paper-like score remains stable while an auto-hiding HUD exposes MIDI status and controls. Progress, History, Ask My Teacher, and Settings currently show “coming later” states.

## Private local exercise Library (6F.7)

Library supports creating, viewing, searching, editing, archiving, and restoring written exercises on the device. Each has a title, category, instructions, and learning purpose. Saved edits retain earlier revisions and stable exercise identity. Active and Archived lists remain available after reopening. Failures support retry or a fresh read without reporting an unverified save as successful.

Exercises are guidance, not automatically playable notation or scheduled programme assignments. Library does not launch MIDI Practice, import documents, create templates, or modify the current Today plan. Exercises are private/local; teacher sharing, AI coaching, and hosted synchronisation are not implemented.

## Implemented but not yet exposed as complete workflows

- A twelve-week programme and mastery domain beginning at Beyer Op. 101 No. 63.
- Local SwiftData models and repositories for active progress, completions, sessions, attempts, reflections, and mastery decisions.
- Today presentation state that can combine programme position, persisted progress, mastery, and reference-material availability.
- A logical catalogue for Beyer and supporting practice material; the source documents are not bundled or openable in the app.
- A limited MusicXML importer and a development-only Verovio fixture renderer.

Milestone 6F.4 connects only the generated sight-reading assignment to an explicit session flow: preparation, Start Session, MIDI Practice, End & Save, immediate summary, and return to Today. Preparation shows the assignment goal and planned duration and lets the learner choose Treble/Bass and a natural-note range. Configuration and reset are locked while the assigned session is active. Other assignments cannot launch in-app Practice; Beyer is never substituted with random notation.

End & Save records one stopped session with its stable programme/week/day/block/assignment/source context and timestamps. Numeric statistics are temporary feedback in the immediate summary, not saved history. Ending does not mark an assignment complete, evaluate mastery, create attempts/reflections, or advance programme position. Standalone Practice remains available without persistence.

Temporary inactivity suspends MIDI input. Backgrounding freezes the session at the observed time; returning offers save or discard, not resume. Discard performs no write. Force-quit recovery is not supported: unsaved sessions may be lost. No duration is invented after termination.

Milestone 6F.5 adds explicit learner-reported completion and undo for every assignment in the current saved day, including work practised outside Pianovo and recovery/reflection work. Confirming Beyer No. 63 requires acknowledging both Seconda and Prima as parts of one assignment. These acknowledgements are not component-level progress records or evidence of mastery. Undo returns the assignment to Not started and clears its completion time while keeping sessions, notes, and mastery records.

Completion is independent of End & Save. It writes only the existing assignment completion record, never session statistics, a mastery decision, a reflection, or a new programme position. Failures retain the displayed status until the change is verified; retry keeps the original intent and timestamp. Refresh Today reads durable status and abandons any pending retry, without undoing an earlier successful save.

The remaining foundations must not be presented as working Progress, History, document-library, or imported-song experiences.

## Near-term product direction

- Record the content/template/programme design and future hosted-service boundaries (6F.6).
- Build reusable exercise templates on the verified private local Library foundation (6F.8).
- Add exercise templates, programme-template editing, and independent learner plans in subsequent milestones.
- Connect editable learner plans to Today, with explicit progression defined separately from completion, session saving, and mastery.
- Expose saved history and learner notes, then authorised teacher review.
- Add document access and score-aligned analysis through their own scoped milestones.

## Longer-term vision

- Grand-staff, two-hand, chord, accidental, key-signature, and rhythm-aware practice.
- Interactive MusicXML scores and full-song practice.
- PDF/photo import with optical music recognition and a verification workflow.
- Tempo and note-quality feedback from MIDI first, with audio analysis considered separately.
- Hosted accounts, authorised learner/teacher collaboration, and offline-capable synchronisation.
- AI coaching for independent learners and AI-assisted authoring for teachers, using reviewable content/plan drafts.
- Community sharing of free or paid exercises/templates, creator attribution/rewards, and permitted adaptation.
- Starter content and possible paid continuation; pricing and access rules remain undecided.

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
- No functional Progress, History, teacher, or settings workflows. No exercise-template or programme-editor workflows.
- No programme-advancement controls, automatic mastery, generic guided sessions, or durable active-session recovery.
- No production MusicXML file picker or imported-song practice.
- No PDF/photo import, optical music recognition, or score correction UI.
- No MIDI recording timeline, tempo assessment, audio analysis, or playback.
- No accounts, teacher portal, chat service, cloud sync, or API-key-backed coach.
