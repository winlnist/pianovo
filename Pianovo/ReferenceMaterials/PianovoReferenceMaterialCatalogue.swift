import Foundation

nonisolated enum PianovoReferenceMaterialCatalogue {
    static let beyerNo63ID = materialID("beyer-op101-no-63-edition-peters-scan")
    static let beyerScanDocumentID = documentID("beyer-op101-edition-peters-88-page-scan")

    static func catalogue() -> ReferenceMaterialCatalogue {
        ReferenceMaterialCatalogue(materials: materials)
    }

    static func resolver(
        availabilityProvider: any DocumentAvailabilityProviding = DefaultUnavailableDocumentAvailabilityProvider()
    ) -> ReferenceMaterialResolver {
        ReferenceMaterialResolver(
            catalogue: catalogue(),
            sourceMappings: sourceMappings,
            availabilityProvider: availabilityProvider
        )
    }

    static let sourceMappings: [ExerciseSourceID: ReferenceMaterialID] = [
        sourceID("beyer-op101-no-63"): beyerNo63ID
    ]

    private static let materials: [ReferenceMaterial] = [
        ReferenceMaterial(
            id: beyerNo63ID,
            title: "Beyer Op. 101 No. 63",
            kind: .beyerExercise,
            formats: [.pdf],
            languages: [.german, .english, .french],
            documentDescriptors: [
                ReferenceDocumentDescriptor(
                    id: beyerScanDocumentID,
                    expectedFilename: "Beyer_-_Op.101_-_Vorschule_im_Klavierspiel.pdf",
                    format: .pdf,
                    pageCount: 88,
                    audioDurationSeconds: nil,
                    descriptorNote: "Inspected 88-page Edition Peters scan only; page indices must not be applied to another Beyer PDF or edition."
                )
            ],
            components: [
                ReferenceMaterialComponent(
                    id: componentID("beyer-op101-no-63-seconda"),
                    title: "Seconda",
                    role: .seconda,
                    requiredForCompleteExercise: true,
                    pdfPageLocator: PDFPageLocator(
                        documentDescriptorID: beyerScanDocumentID,
                        pdfKitPageIndex: 45,
                        printedPageLabel: "46"
                    ),
                    pdfExcerptHint: PDFExcerptHint(
                        description: "Top portion identified by audit; exact crop rectangle deferred to visual verification.",
                        exactCropDeferred: true
                    )
                ),
                ReferenceMaterialComponent(
                    id: componentID("beyer-op101-no-63-prima"),
                    title: "Prima",
                    role: .prima,
                    requiredForCompleteExercise: true,
                    pdfPageLocator: PDFPageLocator(
                        documentDescriptorID: beyerScanDocumentID,
                        pdfKitPageIndex: 46,
                        printedPageLabel: "47"
                    ),
                    pdfExcerptHint: PDFExcerptHint(
                        description: "Top portion identified by audit; exact crop rectangle deferred to visual verification.",
                        exactCropDeferred: true
                    )
                )
            ],
            attribution: ReferenceMaterialAttribution(
                edition: "Edition Peters",
                creator: "Adobe Acrobat 7.0",
                producer: "Adobe Acrobat 7.0 Image Conversion Plug-in",
                visibleCredit: "Ferd. Beyer, Vorschule im Klavierspiel, Op. 101"
            ),
            rightsStatus: .unknown,
            accessRequirement: .userProvidedDocument,
            programmeUseHint: "Week 1 active Beyer exercise; both Prima and Seconda are required for the complete exercise."
        ),
        pdfMaterial(
            id: "blues-scale-1-octave",
            title: "Blues Scale in All 12 Keys",
            kind: .scale,
            expectedFilename: "Blues_scale_1_octave.pdf",
            pageCount: 2,
            languages: [.english],
            attribution: ReferenceMaterialAttribution(
                edition: nil,
                creator: "MuseScore Version: 3.6.2",
                producer: "Qt 5.9.8",
                visibleCredit: "Arranged by Andrew D. Gordon"
            ),
            programmeUseHint: "Potential technique or improvisation reference; not assigned by catalogue inclusion."
        ),
        pdfMaterial(
            id: "c-major-chord-progression",
            title: "C Major Chord Progression",
            kind: .chordProgression,
            expectedFilename: "C Maj Chord Progression.pdf",
            pageCount: 1,
            languages: [.english],
            attribution: museScoreAttribution(title: "C Maj Chord Progression"),
            programmeUseHint: "Potential repertoire and harmony reference; alternate-language pair with Progression Do Majeur."
        ),
        audioMaterial(
            id: "c-major-chord-progression-audio",
            title: "C Major Chord Progression Audio",
            expectedFilename: "C Maj Chord Progression.m4a",
            durationSeconds: 59.371973,
            languages: [.english],
            programmeUseHint: "Potential audio companion for C major harmony; not assigned by catalogue inclusion."
        ),
        pdfMaterial(
            id: "progression-do-majeur",
            title: "Progression Do Majeur",
            kind: .chordProgression,
            expectedFilename: "Progression Do Majeur 2.pdf",
            pageCount: 1,
            languages: [.french],
            attribution: museScoreAttribution(title: nil),
            programmeUseHint: "French alternate-language version of the C major progression."
        ),
        pdfMaterial(
            id: "g-major-chord-progression",
            title: "G Major Chord Progression",
            kind: .chordProgression,
            expectedFilename: "G Major Progression.pdf",
            pageCount: 1,
            languages: [.english],
            attribution: museScoreAttribution(title: nil),
            programmeUseHint: "Potential repertoire and harmony reference; alternate-language pair with Progression Sol Majeur."
        ),
        pdfMaterial(
            id: "progression-sol-majeur",
            title: "Progression Sol Majeur",
            kind: .chordProgression,
            expectedFilename: "Progression Sol Majeur.pdf",
            pageCount: 1,
            languages: [.french],
            attribution: museScoreAttribution(title: nil),
            programmeUseHint: "French alternate-language version of the G major progression."
        ),
        pdfMaterial(
            id: "chord-inversion-exercise",
            title: "Chord Inversions",
            kind: .chordInversion,
            expectedFilename: "Chord Inversion Exercise 2.pdf",
            pageCount: 1,
            languages: [.english],
            attribution: museScoreAttribution(title: "Untitled score"),
            programmeUseHint: "Potential harmony reference; not assigned by catalogue inclusion."
        ),
        pdfMaterial(
            id: "ii-v-i-jazz-chord-progression",
            title: "II-V-I Jazz Chord Progression",
            kind: .jazzHarmony,
            expectedFilename: "II-V-I Jazz Chord Progression.pdf",
            pageCount: 2,
            languages: [.english],
            attribution: ReferenceMaterialAttribution(
                edition: nil,
                creator: "Preview",
                producer: "Mac OS X 10.9.5 Quartz PDFContext",
                visibleCredit: "II-V-I Reference Chart in all Keys"
            ),
            programmeUseHint: "Potential later jazz harmony reference; not assigned by catalogue inclusion."
        ),
        pdfMaterial(
            id: "chromatic-scale",
            title: "Chromatic Scale",
            kind: .scale,
            expectedFilename: "Chromatic_Scale.pdf",
            pageCount: 1,
            languages: [.english],
            attribution: ReferenceMaterialAttribution(
                edition: nil,
                creator: nil,
                producer: "Skia/PDF m141 Google Docs Renderer",
                visibleCredit: "CHROMATIC SCALE"
            ),
            programmeUseHint: "Potential technique reference; not assigned by catalogue inclusion."
        ),
        pdfMaterial(
            id: "major-scales-1-octave",
            title: "One Octave Major Scales",
            kind: .scale,
            expectedFilename: "Major_Scales_1_octave.pdf",
            pageCount: 3,
            languages: [.english],
            attribution: ReferenceMaterialAttribution(
                edition: nil,
                creator: "Finale",
                producer: "macOS Version 10.14.6 Quartz PDFContext",
                visibleCredit: "Courtesy of Gilbert DeBenedetti; gmajormusictheory.org"
            ),
            programmeUseHint: "Potential technique reference; not assigned by catalogue inclusion."
        ),
        pdfMaterial(
            id: "major-scales-2-octaves",
            title: "Major Scales for Piano",
            kind: .scale,
            expectedFilename: "Major_Scales_2_octaves.pdf",
            pageCount: 2,
            languages: [.english],
            attribution: ReferenceMaterialAttribution(
                edition: nil,
                creator: "PScript5.dll Version 5.2",
                producer: "Acrobat Distiller 7.0.5 (Windows)",
                visibleCredit: "Piano Street"
            ),
            programmeUseHint: "Potential technique reference; not assigned by catalogue inclusion."
        ),
        pdfMaterial(
            id: "minor-scales-1-octave",
            title: "One Octave Minor Scales",
            kind: .scale,
            expectedFilename: "Minor_Scales_1_octave.pdf",
            pageCount: 3,
            languages: [.english],
            attribution: ReferenceMaterialAttribution(
                edition: nil,
                creator: "Finale 2007",
                producer: "Mac OS X 10.4.9 Quartz PDFContext",
                visibleCredit: "Courtesy of Gilbert DeBenedetti; gmajormusictheory.org"
            ),
            programmeUseHint: "Potential technique reference; not assigned by catalogue inclusion."
        ),
        pdfMaterial(
            id: "minor-scales-2-octaves",
            title: "Harmonic Minor Scales",
            kind: .scale,
            expectedFilename: "Minor_Scales_2_octaves.pdf",
            pageCount: 2,
            languages: [.english],
            attribution: ReferenceMaterialAttribution(
                edition: nil,
                creator: "PScript5.dll Version 5.2",
                producer: "Acrobat Distiller 7.0.5 (Windows)",
                visibleCredit: "Piano Street"
            ),
            programmeUseHint: "Potential technique reference; not assigned by catalogue inclusion."
        ),
        pdfMaterial(
            id: "major-arpeggios-2-octaves",
            title: "Major Arpeggios 2 Octaves",
            kind: .arpeggio,
            expectedFilename: "Major Arpeggios 2 Octaves.pdf",
            pageCount: 2,
            languages: [.english],
            attribution: ReferenceMaterialAttribution(
                edition: nil,
                creator: "MuseScore Studio Version: 4.5.2",
                producer: "Qt 6.2.4",
                visibleCredit: "Chloe Anghelopoulou"
            ),
            programmeUseHint: "Potential arpeggio reference; not assigned by catalogue inclusion."
        )
    ]

    private static func pdfMaterial(
        id: String,
        title: String,
        kind: ReferenceMaterialKind,
        expectedFilename: String,
        pageCount: Int,
        languages: [ReferenceMaterialLanguage],
        attribution: ReferenceMaterialAttribution?,
        programmeUseHint: String?
    ) -> ReferenceMaterial {
        let materialID = materialID(id)
        let documentID = documentID("\(id)-document")
        return ReferenceMaterial(
            id: materialID,
            title: title,
            kind: kind,
            formats: [.pdf],
            languages: languages,
            documentDescriptors: [
                ReferenceDocumentDescriptor(
                    id: documentID,
                    expectedFilename: expectedFilename,
                    format: .pdf,
                    pageCount: pageCount,
                    audioDurationSeconds: nil,
                    descriptorNote: "Expected filename is descriptive audit metadata, not a device file location."
                )
            ],
            components: [
                ReferenceMaterialComponent(
                    id: componentID("\(id)-full-document"),
                    title: title,
                    role: .fullDocument,
                    requiredForCompleteExercise: false,
                    pdfPageLocator: nil,
                    pdfExcerptHint: nil
                )
            ],
            attribution: attribution,
            rightsStatus: .unknown,
            accessRequirement: .userProvidedDocument,
            programmeUseHint: programmeUseHint
        )
    }

    private static func audioMaterial(
        id: String,
        title: String,
        expectedFilename: String,
        durationSeconds: Double,
        languages: [ReferenceMaterialLanguage],
        programmeUseHint: String?
    ) -> ReferenceMaterial {
        let documentID = documentID("\(id)-document")
        return ReferenceMaterial(
            id: materialID(id),
            title: title,
            kind: .audioCompanion,
            formats: [.audio],
            languages: languages,
            documentDescriptors: [
                ReferenceDocumentDescriptor(
                    id: documentID,
                    expectedFilename: expectedFilename,
                    format: .audio,
                    pageCount: nil,
                    audioDurationSeconds: durationSeconds,
                    descriptorNote: "Expected filename is descriptive audit metadata, not a device file location."
                )
            ],
            components: [
                ReferenceMaterialComponent(
                    id: componentID("\(id)-track"),
                    title: title,
                    role: .audioTrack,
                    requiredForCompleteExercise: false,
                    pdfPageLocator: nil,
                    pdfExcerptHint: nil
                )
            ],
            attribution: nil,
            rightsStatus: .unknown,
            accessRequirement: .userProvidedDocument,
            programmeUseHint: programmeUseHint
        )
    }

    private static func museScoreAttribution(title: String?) -> ReferenceMaterialAttribution {
        ReferenceMaterialAttribution(
            edition: nil,
            creator: "MuseScore Studio Version: 4.5.2",
            producer: "Qt 6.2.4",
            visibleCredit: title
        )
    }

    private static func sourceID(_ rawValue: String) -> ExerciseSourceID {
        ExerciseSourceID(rawValue)!
    }

    private static func materialID(_ rawValue: String) -> ReferenceMaterialID {
        ReferenceMaterialID(rawValue)!
    }

    private static func componentID(_ rawValue: String) -> ReferenceMaterialComponentID {
        ReferenceMaterialComponentID(rawValue)!
    }

    private static func documentID(_ rawValue: String) -> ReferenceDocumentDescriptorID {
        ReferenceDocumentDescriptorID(rawValue)!
    }
}
