import SwiftUI

struct GrandStaffView: View {
    let pitch: Pitch
    let preferredClef: Clef?

    init(pitch: Pitch, preferredClef: Clef? = nil) {
        self.pitch = pitch
        self.preferredClef = preferredClef
    }

    var body: some View {
        Canvas { context, size in
            let layout = GrandStaffLayout(size: size)
            let placement = GrandStaffPlacement(pitch: pitch, preferredClef: preferredClef)
            let inkColor = Color.primary

            drawStaff(.treble, in: &context, layout: layout, inkColor: inkColor)
            drawStaff(.bass, in: &context, layout: layout, inkColor: inkColor)
            drawClef(.treble, in: &context, layout: layout, inkColor: inkColor)
            drawClef(.bass, in: &context, layout: layout, inkColor: inkColor)
            drawLedgerLines(for: placement, in: &context, layout: layout, inkColor: inkColor)
            drawNote(for: placement, in: &context, layout: layout, inkColor: inkColor)
        }
        .aspectRatio(2.6, contentMode: .fit)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let placement = GrandStaffPlacement(pitch: pitch, preferredClef: preferredClef)
        return "\(Self.pitchName(pitch)) on \(placement.clef.rawValue) clef grand staff"
    }

    private func drawStaff(_ clef: Clef, in context: inout GraphicsContext, layout: GrandStaffLayout, inkColor: Color) {
        var path = Path()

        for y in layout.staffLineYValues(for: clef) {
            path.move(to: CGPoint(x: layout.staffLineStartX, y: y))
            path.addLine(to: CGPoint(x: layout.staffLineEndX, y: y))
        }

        context.stroke(path, with: .color(inkColor), lineWidth: layout.staffLineWidth)
    }

    private func drawClef(_ clef: Clef, in context: inout GraphicsContext, layout: GrandStaffLayout, inkColor: Color) {
        var resolved = context.resolve(MusicGlyphs.clefText(clef, size: layout.clefFontSize(for: clef)))
        resolved.shading = .color(inkColor)
        context.draw(resolved, at: layout.clefPosition(for: clef), anchor: .center)
    }

    private func drawLedgerLines(for placement: GrandStaffPlacement, in context: inout GraphicsContext, layout: GrandStaffLayout, inkColor: Color) {
        var path = Path()

        for segment in layout.ledgerLineSegments(for: placement) {
            path.move(to: segment.start)
            path.addLine(to: segment.end)
        }

        context.stroke(path, with: .color(inkColor), lineWidth: layout.staffLineWidth)
    }

    private func drawNote(for placement: GrandStaffPlacement, in context: inout GraphicsContext, layout: GrandStaffLayout, inkColor: Color) {
        let center = layout.noteCenter(for: placement)
        let rect = CGRect(
            x: center.x - (layout.noteheadSize.width / 2),
            y: center.y - (layout.noteheadSize.height / 2),
            width: layout.noteheadSize.width,
            height: layout.noteheadSize.height
        )

        var context = context
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: .degrees(-18))
        context.translateBy(x: -center.x, y: -center.y)
        context.fill(Path(ellipseIn: rect), with: .color(inkColor))
    }

    private static func pitchName(_ pitch: Pitch) -> String {
        let accidental: String

        switch pitch.accidental {
        case .unspecified, .natural:
            accidental = ""
        case .sharp:
            accidental = " sharp"
        case .flat:
            accidental = " flat"
        case .doubleSharp:
            accidental = " double sharp"
        case .doubleFlat:
            accidental = " double flat"
        }

        return "\(pitch.letter.rawValue)\(accidental)\(pitch.octave)"
    }
}

#Preview("Grand Staff Notes") {
    GrandStaffDebugView()
        .padding()
}

#Preview("C2-C6 Staff Checks") {
    VStack(spacing: 18) {
        ForEach([
            Pitch(.c, octave: 2),
            Pitch(.c, octave: 3),
            Pitch(.c, octave: 4),
            Pitch(.c, octave: 5),
            Pitch(.c, octave: 6)
        ], id: \.self) { pitch in
            GrandStaffView(pitch: pitch)
                .frame(height: 150)
        }
    }
    .padding()
}
