# Programme Domain

Milestone 6D adds a framework-independent programme model for Pianovo curriculum planning. It describes planned practice structure and source references only. It does not evaluate user performance, persist progress, inspect PDFs, map score events, or drive SwiftUI.

## Boundary

The Programme Domain is independent from:

- SwiftUI and app navigation.
- CoreMIDI and MIDI analysis.
- PDFKit, Verovio, WebKit, MusicXML parser details, and renderer coordinates.
- Networking and persistence.
- Score-event, measure, page, fingering, and notation-position mappings.

Assignments reference stable `ExerciseSourceID` values through an explicitly supplied `ExerciseSourceCatalogue`. Later adapter layers can map a source such as "Beyer Op. 101 No. 63" to inspected score material and stable `ScoreEventID` values, but those mappings are deliberately outside this milestone.

## Model

```text
PracticeProgramme
  -> ProgrammeWeek
  -> PracticeDay
  -> PracticeBlock
  -> PracticeAssignment

ExerciseSourceCatalogue
  -> ExerciseSource

MasteryRule
  -> MasteryCriterion
```

- `PracticeProgramme` owns ordered weeks, versionable mastery rules, and the stated progression principle: quality, consistency, fluency, speed.
- `ProgrammeWeek` and `PracticeDay` provide calendar structure with deterministic stable identifiers.
- `PracticeBlock` models a timed practice segment such as warm-up, technique, Beyer, repertoire/harmony, sight-reading, review, or reflection.
- `PracticeAssignment` references an `ExerciseSourceID`, a goal, an optional `MasteryRuleID`, and whether the assignment is remediation-only.
- `ExerciseSource` identifies source material by collection/series, source kind, display metadata, and optional exercise identifier. It must not invent pages, measures, fingerings, notes, audio positions, or PDF locations.
- `MasteryState` describes learning status only: `learning`, `stabilizing`, `nearlyMastered`, and `mastered`.
- Manual override is not a mastery state. Future progress/evaluation records should store automatically evaluated state, manually selected state, reason or note, decision date, and rule version used.

## Validation

Validation returns structured `ProgrammeValidationIssue` values instead of crashing or throwing from model initializers.

General structural validation checks:

- Stable IDs are present and unique within their owning collection.
- Week and day numbers are ordered contiguously from 1.
- Day week numbers match their containing week.
- Block durations are positive.
- Required titles, goals, progression principles, and source catalogues are present.
- Assignment source references resolve against the supplied `ExerciseSourceCatalogue`.
- Assignment mastery-rule references resolve against the programme.
- Mastery rules have positive versions, explicit criteria, and valid thresholds.

Pianovo policy validation is separate and checks only the Pianovo twelve-week programme shape:

- Exactly twelve weeks.
- Seven days per week.
- Six practice days and one recovery/reflection day per week.
- Practice days include morning and evening blocks.

This split keeps the core model reusable for other programmes while proving the seeded Pianovo programme follows the approved product policy.

## Seed Data

The seed programme creates the complete twelve-week calendar structure while keeping musical content minimal and source-referenced.

- Each practice week has six practice days and one recovery/reflection day.
- Practice days have morning and evening sessions of 45 minutes each.
- Week 1 explicitly starts Beyer Op. 101 at No. 63.
- Weeks 2-12 use a generic current Beyer sequence source instead of preassigning Nos. 64, 65, or later.
- Earlier Beyer exercises are not part of the default programme and remain available only for future targeted remediation.

The future adaptive sequencing layer should resolve the next Beyer exercise after mastery evaluation confirms the current exercise is ready to advance.
