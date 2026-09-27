import CoreText
import Foundation
import SwiftUI

enum MusicGlyphs {
    struct Glyph: Hashable {
        let smuflCodepoint: String
        let unicodeFallback: String
    }

    static func clef(_ clef: Clef) -> Glyph {
        switch clef {
        case .treble:
            Glyph(smuflCodepoint: "\u{E050}", unicodeFallback: "\u{1D11E}")
        case .bass:
            Glyph(smuflCodepoint: "\u{E062}", unicodeFallback: "\u{1D122}")
        }
    }

    static let noteheadBlack = Glyph(smuflCodepoint: "\u{E0A4}", unicodeFallback: "\u{2669}")
    static let sharp = Glyph(smuflCodepoint: "\u{E262}", unicodeFallback: "\u{266F}")
    static let flat = Glyph(smuflCodepoint: "\u{E260}", unicodeFallback: "\u{266D}")
    static let natural = Glyph(smuflCodepoint: "\u{E261}", unicodeFallback: "\u{266E}")

    static let fontName = "Bravura"
    private static let fontResourceName = "Bravura"
    private static let fontResourceExtension = "otf"
    private static var didAttemptFontRegistration = false
    private static var didRegisterFont = false

    static func clefText(_ clef: Clef, size: CGFloat) -> Text {
        let glyph = MusicGlyphs.clef(clef)

        if registerFontIfNeeded() {
            return Text(glyph.smuflCodepoint)
                .font(.custom(fontName, size: size))
        }

        return Text(glyph.unicodeFallback)
            .font(.system(size: size, design: .serif))
    }

    @discardableResult
    static func registerFontIfNeeded() -> Bool {
        guard !didAttemptFontRegistration else {
            return didRegisterFont
        }

        didAttemptFontRegistration = true

        guard let fontURL = Bundle.main.url(forResource: fontResourceName, withExtension: fontResourceExtension) else {
            didRegisterFont = false
            return false
        }

        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
        didRegisterFont = registered || fontIsAlreadyAvailable()
        return didRegisterFont
    }

    private static func fontIsAlreadyAvailable() -> Bool {
        CTFontCopyPostScriptName(CTFontCreateWithName(fontName as CFString, 12, nil)) as String == fontName
    }
}
