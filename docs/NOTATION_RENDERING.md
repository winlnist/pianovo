# Notation Rendering

Pianovo's Version 0.1 notation renderer is a lightweight SwiftUI/Core Graphics renderer for generated sight-reading practice. It is separate from the Milestone 6B full-score rendering path.

## SMuFL Font

The renderer uses Bravura as its local SMuFL-compatible music font.

- Font file: `Pianovo/Resources/Fonts/Bravura.otf`
- Font name: `Bravura`
- Version found in font metadata: `1.392`
- Copyright holder in font metadata: Steinberg Media Technologies GmbH
- License in font metadata: SIL Open Font License, Version 1.1

The font is bundled with the app and registered at runtime by the rendering layer. The app does not download fonts at runtime.

## Glyph Strategy

SMuFL codepoints are isolated in `Rendering/GrandStaff/MusicGlyphs.swift`.

Current active glyphs:

- Treble clef: SMuFL `U+E050`
- Bass clef: SMuFL `U+E062`

Prepared mappings for future renderer work:

- Black notehead
- Sharp
- Flat
- Natural

MusicDomain does not know about SMuFL, font files, codepoints, or rendering glyphs. It only provides semantic staff placement and ledger-line information.

## Version 0.1 Scope

The original drill renderer remains available and draws:

- Treble and bass staves.
- Bravura treble and bass clefs.
- A single filled notehead.
- Short centered ledger lines.

Milestone 5.6 adds a continuous sight-reading page renderer. It draws:

- A white paper-like music surface with black notation in both Light Mode and Dark Mode.
- Single-staff treble or bass systems.
- Measures with normal barlines.
- Four evenly spaced quarter-note events per measure.
- Filled noteheads with stems.
- Basic stem direction based on staff position.
- Ledger lines.
- A visible current-event cursor.
- Subtle local incorrect feedback near the active note.

Exercise structure and page layout remain separate:

```text
ReadingExercise -> Measures -> Events
SightReadingLayout -> Systems
```

The same generated exercise can reflow into different systems when device width changes. Rotation should not regenerate notes or reset progression.

System layout uses a simple deterministic balancing policy:

```text
available width
-> safe maximum measures per system
-> number of systems required
-> balanced measure distribution
```

Balancing affects only measure grouping into systems. It does not reorder measures, change event identities, regenerate the exercise, or reset the current event.

The renderer intentionally does not draw flags, beams, rests, ties, tuplets, key signatures, accidentals, chords, mixed grand-staff reading, or full imported scores. Those remain future milestones.

## Full-Score Rendering

Milestone 6B adds Verovio as the full-score rendering engine for imported MusicXML fixtures. Verovio is isolated in `Rendering/FullScore` and does not replace `GrandStaffView` or `SightReadingPageView`.

Current full-score flow:

```text
MusicXML fixture
  -> VerovioScoreRenderer
  -> SVG string in FullScoreRenderResult
  -> FullScoreSVGView
```

The debug view uses `WKWebView` only to display Verovio SVG output. WebKit is isolated to `FullScoreSVGView` and must not leak into MusicDomain, Practice, MIDI, or the native drill renderer.

Verovio manages its own engraving and font resources through `VerovioResources.bundle`. The app's bundled Bravura font remains only for the native drill/sight-reading renderer.

Milestone 6B full-score rendering is debug-only. It does not implement imported-song practice, event highlighting inside rendered SVG, click/tap mapping, playback cursor, MIDI-follow mode, file picker UI, or a song library.
