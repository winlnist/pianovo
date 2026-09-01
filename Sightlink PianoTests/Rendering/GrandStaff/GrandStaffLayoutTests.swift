import CoreGraphics
import Testing
@testable import Sightlink_Piano

struct GrandStaffLayoutTests {
    @Test func staffStepToYPositionMovesUpByHalfLineSpacing() {
        let layout = GrandStaffLayout(size: CGSize(width: 320, height: 220))
        let bottomLine = StaffPosition(clef: .treble, pitch: Pitch(.e, octave: 4))
        let firstSpace = StaffPosition(clef: .treble, pitch: Pitch(.f, octave: 4))
        let secondLine = StaffPosition(clef: .treble, pitch: Pitch(.g, octave: 4))

        #expect(approximatelyEqual(layout.yPosition(for: firstSpace), layout.yPosition(for: bottomLine) - (layout.lineSpacing / 2)))
        #expect(approximatelyEqual(layout.yPosition(for: secondLine), layout.yPosition(for: bottomLine) - layout.lineSpacing))
    }

    @Test func higherPitchesHaveLowerYValuesWithinSameClef() {
        let layout = GrandStaffLayout(size: CGSize(width: 320, height: 220))
        let c4 = StaffPosition(clef: .treble, pitch: Pitch(.c, octave: 4))
        let c5 = StaffPosition(clef: .treble, pitch: Pitch(.c, octave: 5))

        #expect(layout.yPosition(for: c5) < layout.yPosition(for: c4))
    }

    @Test func middleCDefaultGrandStaffPlacementUsesTrebleLedgerBelowStaff() {
        let layout = GrandStaffLayout(size: CGSize(width: 320, height: 220))
        let placement = GrandStaffPlacement(pitch: Pitch(.c, octave: 4))
        let noteCenter = layout.noteCenter(for: placement)
        let ledgerLines = layout.ledgerLineSegments(for: placement)

        #expect(placement.clef == .treble)
        #expect(approximatelyEqual(noteCenter.y, layout.trebleBottomLineY + layout.lineSpacing))
        #expect(ledgerLines.count == 1)
        #expect(approximatelyEqual(ledgerLines.first?.start.y, noteCenter.y))
        #expect(approximatelyEqual(ledgerLines.first?.end.y, noteCenter.y))
    }

    @Test func middleCCanBeMappedToBassLedgerAboveStaffWhenRequested() {
        let layout = GrandStaffLayout(size: CGSize(width: 320, height: 220))
        let placement = GrandStaffPlacement(pitch: Pitch(.c, octave: 4), preferredClef: .bass)
        let noteCenter = layout.noteCenter(for: placement)
        let ledgerLines = layout.ledgerLineSegments(for: placement)

        #expect(placement.clef == .bass)
        #expect(approximatelyEqual(noteCenter.y, layout.bassBottomLineY - (layout.lineSpacing * 5)))
        #expect(ledgerLines.count == 1)
        #expect(approximatelyEqual(ledgerLines.first?.start.y, noteCenter.y))
        #expect(approximatelyEqual(ledgerLines.first?.end.y, noteCenter.y))
    }

    @Test func lowBassLedgerLinesConvertToShortSegments() {
        let layout = GrandStaffLayout(size: CGSize(width: 320, height: 220))
        let placement = GrandStaffPlacement(pitch: Pitch(.c, octave: 2))
        let ledgerLines = layout.ledgerLineSegments(for: placement)

        #expect(placement.clef == .bass)
        #expect(ledgerLines.count == 2)
        #expect(approximatelyEqual(ledgerLines[0].start.y, layout.bassBottomLineY + layout.lineSpacing))
        #expect(approximatelyEqual(ledgerLines[1].start.y, layout.bassBottomLineY + (layout.lineSpacing * 2)))
        #expect(approximatelyEqual(ledgerLines[0].end.x - ledgerLines[0].start.x, layout.ledgerLineLength))
        #expect(layout.ledgerLineLength < layout.staffWidth)
    }

    @Test func highTrebleLedgerLinesConvertToShortSegments() {
        let layout = GrandStaffLayout(size: CGSize(width: 320, height: 220))
        let placement = GrandStaffPlacement(pitch: Pitch(.c, octave: 6))
        let ledgerLines = layout.ledgerLineSegments(for: placement)
        let trebleTopLineY = layout.trebleBottomLineY - (layout.lineSpacing * 4)

        #expect(placement.clef == .treble)
        #expect(ledgerLines.count == 2)
        #expect(approximatelyEqual(ledgerLines[0].start.y, trebleTopLineY - layout.lineSpacing))
        #expect(approximatelyEqual(ledgerLines[1].start.y, trebleTopLineY - (layout.lineSpacing * 2)))
        #expect(approximatelyEqual(ledgerLines[0].end.x - ledgerLines[0].start.x, layout.ledgerLineLength))
        #expect(layout.ledgerLineLength < layout.staffWidth)
    }

    @Test func trebleAndBassStaffCoordinateMappingKeepsBassBelowTreble() {
        let layout = GrandStaffLayout(size: CGSize(width: 320, height: 220))

        #expect(layout.bassBottomLineY > layout.trebleBottomLineY)
        #expect(layout.staffLineYValues(for: .treble).count == 5)
        #expect(layout.staffLineYValues(for: .bass).count == 5)
        #expect(layout.staffLineYValues(for: .treble).min()! < layout.staffLineYValues(for: .treble).max()!)
        #expect(layout.staffLineYValues(for: .bass).min()! < layout.staffLineYValues(for: .bass).max()!)
    }

    @Test func layoutScalesWithAvailableSizeWithinExpectedBounds() {
        let compact = GrandStaffLayout(size: CGSize(width: 240, height: 160))
        let regular = GrandStaffLayout(size: CGSize(width: 720, height: 420))

        #expect(regular.lineSpacing > compact.lineSpacing)
        #expect(regular.staffWidth > compact.staffWidth)
        #expect(regular.noteheadSize.width > compact.noteheadSize.width)
    }

    @Test func clefAnchorsUseConventionalReferenceLines() {
        let layout = GrandStaffLayout(size: CGSize(width: 720, height: 420))

        let trebleGLineY = layout.yPosition(for: StaffPosition(clef: .treble, pitch: Pitch(.g, octave: 4)))
        let bassFLineY = layout.yPosition(for: StaffPosition(clef: .bass, pitch: Pitch(.f, octave: 3)))

        #expect(approximatelyEqual(layout.clefAnchorY(for: .treble), trebleGLineY))
        #expect(approximatelyEqual(layout.clefAnchorY(for: .bass), bassFLineY))
    }

    @Test func polishedLayoutKeepsStaffWideAndNoteToRightOfClefs() {
        let layout = GrandStaffLayout(size: CGSize(width: 900, height: 460))

        #expect(layout.staffWidth > 700)
        #expect(layout.noteCenterX > layout.clefPosition(for: .treble).x + (layout.lineSpacing * 4))
        #expect(layout.ledgerLineLength < layout.staffWidth * 0.12)
    }

    private func approximatelyEqual(_ lhs: CGFloat?, _ rhs: CGFloat, tolerance: CGFloat = 0.0001) -> Bool {
        guard let lhs else {
            return false
        }

        return abs(lhs - rhs) <= tolerance
    }

    private func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.0001) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
