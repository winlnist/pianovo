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

See [Reusable Content, Programmes, and Sharing](CONTENT_AND_PROGRAMMES.md) for the design baseline, compatibility constraints, and phased scope. Exercise and programme-template authoring are local workflows; independent learner plans now have local Today integration; hosted services remain planned.

## Current user-facing experience

The app launches into Today, where learners explicitly start the programme at Week 1 Day 1 and view the saved day. Morning, Evening, recovery/reflection, saved assignment/mastery status, and honest material availability are presented without automatic day advancement. Practice is a working continuous single-staff sight-reading experience:

- Choose Treble Reading or Bass Reading.
- Read a generated 64-note exercise arranged into measures and responsive systems.
- Adjust the natural-note range within C4-C6 for treble or C2-C4 for bass.
- Play on a physical MIDI piano.
- Advance after a correct note; remain on the current note after an incorrect attempt.
- Receive a new exercise after completing the current one.
- Review session-only correct, wrong, attempt, accuracy, streak, and completion values.

The paper-like score remains stable while an auto-hiding HUD exposes MIDI status and controls. Progress, Ask My Teacher, and Settings currently show “coming later” states.

## Private local exercise Library (6F.7)

Library supports creating, viewing, searching, editing, archiving, and restoring written exercises on the device. Each has a title, category, instructions, and learning purpose. Saved edits retain earlier revisions and stable exercise identity. Active and Archived lists remain available after reopening. Failures support retry or a fresh read without reporting an unverified save as successful.

Exercises are guidance, not automatically playable notation or scheduled programme assignments. Library exercises do not launch MIDI Practice, import documents, or modify the current Today plan. Exercises are private/local; teacher sharing, AI coaching, and hosted synchronisation are not implemented.

## Reusable exercise templates (6F.8)

Library's Exercise templates section supports private template creation, editing, searching, archiving, and restoration. A template stores a name and exercise defaults: title, category, instructions, learning purpose, and any existing logical material reference. New Template offers a blank form or optional Pianovo starter patterns for warm-up, sight-reading guidance, and reflection; these do not automatically seed the database.

Create exercise opens an editable pre-filled exercise form. Saving creates a new exercise and pins its template revision/name as origin. Repeated use creates independent exercises. Editing or archiving a template never rewrites exercises already created; editing an exercise preserves its original template reference. These are written defaults, not a variable-expression language, generated notation, MIDI assessment, programme scheduling, or AI.

The Library store explicitly migrates from V1 to V2 while preserving old exercise IDs, owner, revisions, and archive state. Progress/history V1 remains unchanged. Templates share the Library's local owner identity; there are no shared accounts or cloud publishing. Manual validation confirmed template navigation and exercise creation from a template.

## Local programme templates (6F.9)

Library's Programme templates section creates reusable arrangements of saved exercises into ordered weeks, days, and named sections. Each placement pins an exercise version and has its own goal and planned minutes. The editor supports recovery/reflection days, adding/reordering/removing structure and placements, and optional blank or Morning/Evening starter structures. Length can be configured up to 104 weeks; the twelve-week seed is not a global restriction. Empty days/sections are allowed while building a template.

Saving/editing retains immutable revisions. Create editable copy produces an independent template with source origin retained; later edits do not change the source or its exercise content. Templates can be searched, archived, restored and reopened from local storage. Existing exercise references remain pinned after exercise edits/archives. Initial 6F.9 use has been manually confirmed; broader device checks remain pending.

Templates remain reusable content. Explicit Use as my programme creates/selects an independent learner plan through 6F.10 below; it does not rewrite the template or the original Today position/history. No teacher sharing, mastery assessment or AI is added.

## Individual learner programmes and Today (6F.10)

Use as my programme in Library creates a private independent plan from a selected template revision and opens its first saved day in Today. The plan retains pinned exercise versions and source origin. Today displays the authored section names, instructions, goals and planned minutes, with self-reported completion and undo. Named sections are not interpreted as clock-based scheduling.

Today → Programmes switches between learner plans and the preserved original twelve-week programme, keeping each position and all original history. Next Day allows continuing after an unfinished-work warning and preserves that work's status; Previous Day revisits earlier saved work. Recovery and week boundaries follow the saved order, and Finish programme presents an explicit end state without wrapping or inferring mastery. Only learner actions move position.

Edit my programme adapts the personal copy, retaining immutable revisions and original records. Unchanged assignments retain status; changed work has a new occurrence identity and starts uncompleted. The current saved day cannot be removed until the learner moves to another day. Changed plan content clears its prior end marker without resetting position or records. Template/exercise edits never rewrite existing learner work.

New authored assignments remain written guidance and do not launch MIDI Practice. The original programme's assigned sight-reading and standalone Practice remain operational. Legacy progress stays in its original store and is not copied/re-keyed into a new plan; the Library V3-to-V4 migration adds private learner records separately. Device validation of 6F.10 is pending. Automatic seed conversion, mastery, document access, rhythm/tempo analysis, cloud sync and teacher/AI features remain future work.

## Local History and private notes (6F.11)

History shows actual saved sessions, original reflections/attempts/mastery decisions when present, independent learner completion/undo, and private notes. It shows recorded duration and historical local-day/time-zone context, without inventing accuracy, tempo or numeric statistics. Standalone Practice remains session-only. Missing or failed history sources are labelled and can be refreshed.

Add private note targets a saved session or learner assignment/day; Note on current day targets the selected started programme day. Notes are explicit, append-only learner reflections stored on this device. Saving does not change position, completion or mastery. Teacher feedback, private teacher lesson notes and shared lesson notes remain planned with separate audiences/permissions. History does not add Progress, remote collaboration or combined deletion/settings features. Manual validation confirmed using History and adding private notes. Restoration after reopening and broader workflow checks remain unconfirmed.

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

The remaining foundations must not be presented as working Progress, document-library, or imported-song experiences.

## Near-term product direction

- Record the content/template/programme design and future hosted-service boundaries (6F.6).
- Validate programme-template and learner-plan workflows on device.
- Keep editable learner-plan progression explicit and separate from completion, session saving, and mastery.
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
- No functional Progress, teacher, or settings workflows.
- No advancement/editing of the original seeded programme; no automatic mastery, generic guided sessions, or durable active-session recovery.
- No production MusicXML file picker or imported-song practice.
- No PDF/photo import, optical music recognition, or score correction UI.
- No MIDI recording timeline, tempo assessment, audio analysis, or playback.
- No accounts, teacher portal, chat service, cloud sync, or API-key-backed coach.
