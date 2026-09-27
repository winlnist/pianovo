# Import Pipeline

Pianovo should eventually support importing structured songs and recognizing notation from PDFs or photos. These capabilities are not part of Version 0.1.

## Goals

The import pipeline should convert external music sources into structured notation that the app can render, inspect, and use for interactive practice.

Long-term source types:

- MusicXML files.
- PDF sheet music.
- Photos or scans of sheet music.

## MusicXML Direction

MusicXML is the preferred first structured import format because it already represents notation semantics.

Milestone 6A adds the first MusicXML import foundation. It is an adapter layer that uses Foundation XML parsing and maps a supported `score-partwise` subset into the Full Score Domain. It is not part of the core Music Domain and does not introduce Verovio, file import UI, playback, or imported-song practice.

The supported 6A subset includes:

- `score-partwise` documents.
- Work or movement title.
- Part list IDs and part names.
- Parts and numbered measures.
- `divisions`-based durations.
- Time signatures.
- Key signatures by fifths and major/minor mode.
- Treble and bass clefs.
- Staff and voice assignment.
- Pitched notes, rests, and simple MusicXML chords using `<chord/>`.
- Measure cursor movement using `<backup>` and `<forward>`.
- Natural, sharp, flat, double-sharp, and double-flat accidentals from integer `alter` values.
- Basic tie start/stop state.
- Deterministic score event IDs derived from imported part, measure, and event order.

The importer uses one exact measure cursor per MusicXML measure. Notes and rests are placed at the current cursor position, then advance the cursor by their `duration` measured in the current `divisions` value. Explicit `<chord/>` notes attach to the immediately preceding compatible note/chord and do not advance the cursor. `<backup>` moves the cursor backward by its duration, and `<forward>` moves it forward without creating a score event. Cursor movement is converted into `MusicalFraction`/`MusicalPosition` values and does not use floating point.

This supports common multi-voice and two-staff piano files where one voice is written, a `<backup>` returns to the beginning or another earlier point in the measure, and another voice or staff is written at overlapping positions. Simultaneous notes in separate voices remain separate `ScoreEvent` values; only explicit MusicXML `<chord/>` groups become `ScoreChord` events.

Later work should broaden support for:

- More MusicXML score variants.
- Transposition, tuplets, beams, slurs, articulations, dynamics, repeats, directions, lyrics, and layout hints where they matter.
- File picker/import UI.
- Use renderer adapters to display imported music.
- Attach practice results to stable event identifiers.

## Full-Score Rendering

Milestone 6B adds Verovio as the current full-score rendering engine because it is designed for engraving structured notation. The architecture should remain renderer-agnostic.

The app should avoid binding the Music Domain directly to Verovio types. Instead:

- The Music Domain owns musical truth.
- The MusicXML importer maps supported MusicXML into the Score Domain.
- `VerovioScoreRenderer` loads the same MusicXML source directly into Verovio and renders SVG.
- Renderer-specific interaction is translated back into stable domain event identifiers.

For simple drills, a lightweight native SwiftUI/Core Graphics renderer is preferred.

Verovio is integrated through Swift Package Manager from `https://github.com/rism-digital/verovio.git` at the commit for the official `version-5.5.0` tag. The package product is `VerovioToolkit`. Verovio provides `VerovioResources.bundle`, and the renderer sets the toolkit resource path from that bundle before loading MusicXML. Verovio manages its own engraving/font pipeline; the app's Bravura drill-renderer font is not reused manually by Verovio.

The current SVG display is debug-only and isolated behind `FullScoreSVGView`, which uses `WKWebView` to show Verovio SVG output. This is not a broad web rendering architecture.

## PDF and Photo Recognition

PDF/photo recognition is a future optical music recognition workflow, not a Version 0.1 feature.

Possible pipeline:

1. Import image or PDF.
2. Normalize pages or photos.
3. Detect staves, clefs, measures, noteheads, stems, accidentals, rests, and rhythm.
4. Convert recognition output into MusicXML or a direct domain model.
5. Present a correction and verification UI.
6. Save structured notation.
7. Render as an interactive score.
8. Use stable event identifiers for practice results.

## Recognition Risks

Optical music recognition is error-prone. The product should assume users may need to correct imported notation before practicing.

Key risks:

- Poor photo angle or lighting.
- Low-resolution scans.
- Handwritten notation.
- Dense polyphony.
- Multiple voices.
- Cross-staff notation.
- Ambiguous accidentals.
- Complex rhythms.

## Architectural Rules

- Do not put recognition output directly into UI-only models.
- Do not store practice progress inside imported score models.
- Do not make PDF/photo recognition a dependency of the Music Domain.
- Keep importers as adapters into structured notation.
- Keep event identifiers stable after import correction where possible.

## Version 0.1 Boundary

Version 0.1 should not include:

- PDF import.
- Photo import.
- Optical music recognition.
- AI recognition.
- Full-song playback.
- Interactive imported-song practice.
