import CoreGraphics

nonisolated struct GrandStaffLayout: Hashable {
    let size: CGSize
    let horizontalInset: CGFloat
    let staffWidth: CGFloat
    let lineSpacing: CGFloat
    let trebleBottomLineY: CGFloat
    let bassBottomLineY: CGFloat
    let noteCenterX: CGFloat
    let noteheadSize: CGSize
    let ledgerLineLength: CGFloat
    let staffLineWidth: CGFloat

    init(size: CGSize) {
        self.size = size

        let shortestSide = min(size.width, size.height)
        lineSpacing = max(9, min(24, shortestSide / 13))
        horizontalInset = max(lineSpacing * 2.2, size.width * 0.06)
        staffWidth = max(0, size.width - (horizontalInset * 2))
        noteCenterX = horizontalInset + (staffWidth * 0.62)
        noteheadSize = CGSize(width: lineSpacing * 1.48, height: lineSpacing * 1.02)
        ledgerLineLength = lineSpacing * 2.75
        staffLineWidth = max(1.1, lineSpacing * 0.08)

        let grandStaffHeight = lineSpacing * 13
        let topY = max(lineSpacing * 1.5, (size.height - grandStaffHeight) / 2)
        trebleBottomLineY = topY + (lineSpacing * 4)
        bassBottomLineY = topY + (lineSpacing * 13)
    }

    var staffLineStartX: CGFloat {
        horizontalInset
    }

    var staffLineEndX: CGFloat {
        horizontalInset + staffWidth
    }

    func bottomLineY(for clef: Clef) -> CGFloat {
        switch clef {
        case .treble:
            trebleBottomLineY
        case .bass:
            bassBottomLineY
        }
    }

    func staffLineYValues(for clef: Clef) -> [CGFloat] {
        let bottomLineY = bottomLineY(for: clef)
        return (0..<5).map { lineIndex in
            bottomLineY - (CGFloat(lineIndex) * lineSpacing)
        }
    }

    func yPosition(for staffPosition: StaffPosition) -> CGFloat {
        bottomLineY(for: staffPosition.clef) - (CGFloat(staffPosition.stepFromBottomLine) * lineSpacing / 2)
    }

    func noteCenter(for placement: GrandStaffPlacement) -> CGPoint {
        CGPoint(x: noteCenterX, y: yPosition(for: placement.staffPosition))
    }

    func ledgerLineSegments(for placement: GrandStaffPlacement) -> [LedgerLineSegment] {
        let staffPosition = placement.staffPosition
        let ledgerLines = staffPosition.ledgerLines
        let bottomLineY = bottomLineY(for: placement.clef)
        let topLineY = bottomLineY - (lineSpacing * 4)
        let startX = noteCenterX - (ledgerLineLength / 2)
        let endX = noteCenterX + (ledgerLineLength / 2)

        var segments: [LedgerLineSegment] = []

        if ledgerLines.belowStaff > 0 {
            segments += (1...ledgerLines.belowStaff).map { index in
                LedgerLineSegment(start: CGPoint(x: startX, y: bottomLineY + (CGFloat(index) * lineSpacing)),
                                  end: CGPoint(x: endX, y: bottomLineY + (CGFloat(index) * lineSpacing)))
            }
        }

        if ledgerLines.aboveStaff > 0 {
            segments += (1...ledgerLines.aboveStaff).map { index in
                LedgerLineSegment(start: CGPoint(x: startX, y: topLineY - (CGFloat(index) * lineSpacing)),
                                  end: CGPoint(x: endX, y: topLineY - (CGFloat(index) * lineSpacing)))
            }
        }

        return segments
    }

    func clefPosition(for clef: Clef) -> CGPoint {
        let x = horizontalInset + (lineSpacing * 2.45)

        switch clef {
        case .treble:
            return CGPoint(x: x, y: clefAnchorY(for: .treble) + (lineSpacing * 0.22))
        case .bass:
            return CGPoint(x: x, y: clefAnchorY(for: .bass) - (lineSpacing * 0.02))
        }
    }

    func clefFontSize(for clef: Clef) -> CGFloat {
        switch clef {
        case .treble:
            lineSpacing * 6.35
        case .bass:
            lineSpacing * 4.9
        }
    }

    func clefAnchorY(for clef: Clef) -> CGFloat {
        switch clef {
        case .treble:
            return yPosition(for: StaffPosition(clef: .treble, pitch: Pitch(.g, octave: 4)))
        case .bass:
            return yPosition(for: StaffPosition(clef: .bass, pitch: Pitch(.f, octave: 3)))
        }
    }
}

nonisolated struct LedgerLineSegment: Hashable {
    let start: CGPoint
    let end: CGPoint
}
