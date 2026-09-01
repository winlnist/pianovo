import SwiftUI

struct SightReadingPageView: View {
    let exercise: ReadingExercise
    let currentEventIndex: Int
    let feedback: PracticeFeedback
    var layoutPolicy = SightReadingLayoutPolicy()

    var body: some View {
        GeometryReader { proxy in
            let systems = layoutPolicy.systems(for: exercise, availableWidth: proxy.size.width - 72)

            Canvas { context, size in
                drawPage(in: &context, size: size, systems: systems)
            }
            .background(Color.white)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var accessibilityLabel: String {
        "Sight-reading exercise, \(exercise.mode.rawValue), event \(currentEventIndex + 1) of \(exercise.events.count)"
    }

    private func drawPage(in context: inout GraphicsContext, size: CGSize, systems: [SightReadingSystem]) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

        let metrics = PageMetrics(size: size)
        var eventStartIndex = 0

        for system in systems {
            drawSystem(
                system,
                eventStartIndex: eventStartIndex,
                in: &context,
                metrics: metrics
            )
            eventStartIndex += system.measures.reduce(0) { $0 + $1.events.count }
        }
    }

    private func drawSystem(
        _ system: SightReadingSystem,
        eventStartIndex: Int,
        in context: inout GraphicsContext,
        metrics: PageMetrics
    ) {
        let topY = metrics.topMargin + (CGFloat(system.index) * metrics.systemDistance)
        let bottomLineY = topY + metrics.staffTopPadding + (metrics.lineSpacing * 4)
        let clef = exercise.mode.clef
        let staffStartX = metrics.leftMargin
        let staffEndX = metrics.size.width - metrics.rightMargin
        let measureAreaStartX = staffStartX + metrics.clefWidth
        let measureWidth = max(metrics.minimumMeasureWidth, (staffEndX - measureAreaStartX) / CGFloat(max(1, system.measures.count)))

        drawStaffLines(
            startX: staffStartX,
            endX: staffEndX,
            bottomLineY: bottomLineY,
            in: &context,
            metrics: metrics
        )
        drawClef(clef, at: CGPoint(x: staffStartX + (metrics.clefWidth * 0.34), y: bottomLineY), in: &context, metrics: metrics)

        var globalEventIndex = eventStartIndex

        for (measureOffset, measure) in system.measures.enumerated() {
            let measureStartX = measureAreaStartX + (CGFloat(measureOffset) * measureWidth)
            drawBarline(x: measureStartX, bottomLineY: bottomLineY, in: &context, metrics: metrics)

            for (eventOffset, event) in measure.events.enumerated() {
                let noteX = measureStartX + (measureWidth * (CGFloat(eventOffset) + 0.65) / CGFloat(max(1, measure.events.count)))
                let placement = StaffPosition(clef: clef, pitch: event.expectedPitch)
                let center = CGPoint(
                    x: noteX,
                    y: bottomLineY - (CGFloat(placement.stepFromBottomLine) * metrics.lineSpacing / 2)
                )

                drawLedgerLines(for: placement, center: center, bottomLineY: bottomLineY, in: &context, metrics: metrics)
                drawEventFeedback(at: center, isCurrent: globalEventIndex == currentEventIndex, in: &context, metrics: metrics)
                drawQuarterNote(at: center, placement: placement, in: &context, metrics: metrics)

                globalEventIndex += 1
            }

            if measureOffset == system.measures.count - 1 {
                drawBarline(x: measureStartX + measureWidth, bottomLineY: bottomLineY, in: &context, metrics: metrics)
            }
        }
    }

    private func drawStaffLines(
        startX: CGFloat,
        endX: CGFloat,
        bottomLineY: CGFloat,
        in context: inout GraphicsContext,
        metrics: PageMetrics
    ) {
        var path = Path()

        for lineIndex in 0..<5 {
            let y = bottomLineY - (CGFloat(lineIndex) * metrics.lineSpacing)
            path.move(to: CGPoint(x: startX, y: y))
            path.addLine(to: CGPoint(x: endX, y: y))
        }

        context.stroke(path, with: .color(.black), lineWidth: metrics.staffLineWidth)
    }

    private func drawClef(_ clef: Clef, at point: CGPoint, in context: inout GraphicsContext, metrics: PageMetrics) {
        let fontSize = clef == .treble ? metrics.lineSpacing * 5.25 : metrics.lineSpacing * 4.05
        var text = context.resolve(MusicGlyphs.clefText(clef, size: fontSize))
        text.shading = .color(.black)

        let yOffset = clef == .treble ? -(metrics.lineSpacing * 1.0) : -(metrics.lineSpacing * 2.0)
        context.draw(text, at: CGPoint(x: point.x, y: point.y + yOffset), anchor: .center)
    }

    private func drawBarline(x: CGFloat, bottomLineY: CGFloat, in context: inout GraphicsContext, metrics: PageMetrics) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: bottomLineY))
        path.addLine(to: CGPoint(x: x, y: bottomLineY - (metrics.lineSpacing * 4)))
        context.stroke(path, with: .color(.black), lineWidth: metrics.staffLineWidth)
    }

    private func drawLedgerLines(
        for placement: StaffPosition,
        center: CGPoint,
        bottomLineY: CGFloat,
        in context: inout GraphicsContext,
        metrics: PageMetrics
    ) {
        let topLineY = bottomLineY - (metrics.lineSpacing * 4)
        let startX = center.x - (metrics.ledgerLineLength / 2)
        let endX = center.x + (metrics.ledgerLineLength / 2)
        var path = Path()

        if placement.ledgerLines.belowStaff > 0 {
            for index in 1...placement.ledgerLines.belowStaff {
                let y = bottomLineY + (CGFloat(index) * metrics.lineSpacing)
                path.move(to: CGPoint(x: startX, y: y))
                path.addLine(to: CGPoint(x: endX, y: y))
            }
        }

        if placement.ledgerLines.aboveStaff > 0 {
            for index in 1...placement.ledgerLines.aboveStaff {
                let y = topLineY - (CGFloat(index) * metrics.lineSpacing)
                path.move(to: CGPoint(x: startX, y: y))
                path.addLine(to: CGPoint(x: endX, y: y))
            }
        }

        context.stroke(path, with: .color(.black), lineWidth: metrics.staffLineWidth)
    }

    private func drawEventFeedback(
        at center: CGPoint,
        isCurrent: Bool,
        in context: inout GraphicsContext,
        metrics: PageMetrics
    ) {
        guard isCurrent else {
            return
        }

        let color: Color
        let lineWidth: CGFloat

        switch feedback {
        case .incorrect:
            color = .red
            lineWidth = metrics.staffLineWidth * 2.4
        case .neutral, .correct:
            color = .blue
            lineWidth = metrics.staffLineWidth * 2
        }

        let rect = CGRect(
            x: center.x - (metrics.noteheadSize.width * 1.25),
            y: center.y - (metrics.noteheadSize.height * 1.35),
            width: metrics.noteheadSize.width * 2.5,
            height: metrics.noteheadSize.height * 2.7
        )
        context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.72)), lineWidth: lineWidth)
    }

    private func drawQuarterNote(
        at center: CGPoint,
        placement: StaffPosition,
        in context: inout GraphicsContext,
        metrics: PageMetrics
    ) {
        drawNotehead(at: center, in: &context, metrics: metrics)

        let stemDirection = StemDirection(staffPosition: placement)
        let stemStartX = center.x + (stemDirection == .up ? metrics.noteheadSize.width * 0.42 : -metrics.noteheadSize.width * 0.42)
        let stemStartY = center.y
        let stemEndY = center.y + (stemDirection == .up ? -metrics.stemLength : metrics.stemLength)

        var path = Path()
        path.move(to: CGPoint(x: stemStartX, y: stemStartY))
        path.addLine(to: CGPoint(x: stemStartX, y: stemEndY))
        context.stroke(path, with: .color(.black), lineWidth: metrics.stemLineWidth)
    }

    private func drawNotehead(at center: CGPoint, in context: inout GraphicsContext, metrics: PageMetrics) {
        let rect = CGRect(
            x: center.x - (metrics.noteheadSize.width / 2),
            y: center.y - (metrics.noteheadSize.height / 2),
            width: metrics.noteheadSize.width,
            height: metrics.noteheadSize.height
        )

        var rotatedContext = context
        rotatedContext.translateBy(x: center.x, y: center.y)
        rotatedContext.rotate(by: .degrees(-18))
        rotatedContext.translateBy(x: -center.x, y: -center.y)
        rotatedContext.fill(Path(ellipseIn: rect), with: .color(.black))
    }
}

private enum StemDirection {
    case up
    case down

    init(staffPosition: StaffPosition) {
        self = staffPosition.stepFromBottomLine < 4 ? .up : .down
    }
}

private struct PageMetrics {
    let size: CGSize
    let lineSpacing: CGFloat
    let staffLineWidth: CGFloat
    let stemLineWidth: CGFloat
    let noteheadSize: CGSize
    let ledgerLineLength: CGFloat
    let stemLength: CGFloat
    let topMargin: CGFloat
    let leftMargin: CGFloat
    let rightMargin: CGFloat
    let staffTopPadding: CGFloat
    let systemDistance: CGFloat
    let clefWidth: CGFloat
    let minimumMeasureWidth: CGFloat

    init(size: CGSize) {
        self.size = size
        let shortestSide = min(size.width, size.height)
        lineSpacing = max(8.5, min(13.5, shortestSide / 54))
        staffLineWidth = max(0.9, lineSpacing * 0.075)
        stemLineWidth = max(1.1, lineSpacing * 0.09)
        noteheadSize = CGSize(width: lineSpacing * 1.42, height: lineSpacing * 0.96)
        ledgerLineLength = lineSpacing * 2.35
        stemLength = lineSpacing * 3.2
        topMargin = max(28, lineSpacing * 3.2)
        leftMargin = max(28, min(58, size.width * 0.055))
        rightMargin = leftMargin
        staffTopPadding = lineSpacing * 3.0
        systemDistance = lineSpacing * 8.6
        clefWidth = lineSpacing * 4.75
        minimumMeasureWidth = lineSpacing * 7.2
    }
}

#Preview("Treble Portrait Page") {
    SightReadingPageView(
        exercise: PreviewExercises.treble,
        currentEventIndex: 0,
        feedback: .neutral
    )
    .frame(width: 768, height: 960)
}

#Preview("Bass Landscape Page") {
    SightReadingPageView(
        exercise: PreviewExercises.bass,
        currentEventIndex: 24,
        feedback: .incorrect(playedPitch: Pitch(.e, octave: 2))
    )
    .frame(width: 1024, height: 680)
}

private enum PreviewExercises {
    static let treble = makeExercise(mode: .trebleReading, range: PracticeMode.trebleReading.defaultPitchRange)
    static let bass = makeExercise(mode: .bassReading, range: PracticeMode.bassReading.defaultPitchRange)

    private static func makeExercise(mode: PracticeMode, range: PitchRange) -> ReadingExercise {
        var generator = ReadingExerciseGenerator(
            configuration: PracticeConfiguration(pitchRange: range, mode: mode)
        ) { upperBound in
            upperBound - 1
        }
        return generator.nextExercise()
    }
}
