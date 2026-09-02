import Foundation
import Testing
@testable import Sightlink_Piano

struct ReferenceMaterialCatalogueTests {
    @Test func stableSourceIDResolutionFindsKnownMaterial() throws {
        let resolver = PianovoReferenceMaterialCatalogue.resolver(
            availabilityProvider: AvailableDocumentProvider()
        )
        let sourceID = try #require(ExerciseSourceID("beyer-op101-no-63"))

        let resolution = resolver.resolve(sourceID: sourceID)

        #expect(resolution.material?.id == PianovoReferenceMaterialCatalogue.beyerNo63ID)
        #expect(resolution.issue == nil)
        #expect(resolution.availability == .available(DocumentAccessReference("test-document-token")!))
    }

    @Test func unknownSourceReturnsStructuredResolutionIssue() throws {
        let resolver = PianovoReferenceMaterialCatalogue.resolver()
        let sourceID = try #require(ExerciseSourceID("unknown-source"))

        let resolution = resolver.resolve(sourceID: sourceID)

        #expect(resolution.material == nil)
        #expect(resolution.availability == nil)
        #expect(resolution.issue == .unknownSource(sourceID))
    }

    @Test func knownMaterialDefaultsToUnavailableUntilADeviceAdapterResolvesAccess() throws {
        let resolver = PianovoReferenceMaterialCatalogue.resolver()
        let sourceID = try #require(ExerciseSourceID("beyer-op101-no-63"))

        let resolution = resolver.resolve(sourceID: sourceID)

        #expect(resolution.material?.id == PianovoReferenceMaterialCatalogue.beyerNo63ID)
        #expect(resolution.availability == .unavailable(reason: .notImported))
        #expect(resolution.issue == .unavailable(.notImported))
    }

    @Test func resolverCanRepresentKnownAndAvailableDocumentAccess() throws {
        let resolver = PianovoReferenceMaterialCatalogue.resolver(
            availabilityProvider: AvailableDocumentProvider()
        )
        let sourceID = try #require(ExerciseSourceID("beyer-op101-no-63"))

        let resolution = resolver.resolve(sourceID: sourceID)

        #expect(resolution.availability == .available(DocumentAccessReference("test-document-token")!))
        #expect(resolution.issue == nil)
    }

    @Test func catalogueContentsAreDeterministic() {
        let catalogue = PianovoReferenceMaterialCatalogue.catalogue()

        #expect(catalogue.materials.map(\.id.rawValue) == [
            "beyer-op101-no-63-edition-peters-scan",
            "blues-scale-1-octave",
            "c-major-chord-progression",
            "c-major-chord-progression-audio",
            "progression-do-majeur",
            "g-major-chord-progression",
            "progression-sol-majeur",
            "chord-inversion-exercise",
            "ii-v-i-jazz-chord-progression",
            "chromatic-scale",
            "major-scales-1-octave",
            "major-scales-2-octaves",
            "minor-scales-1-octave",
            "minor-scales-2-octaves",
            "major-arpeggios-2-octaves"
        ])
        #expect(catalogue.materials.count == 15)
    }

    @Test func beyerNumberSixtyThreeResolvesToPrimaAndSecondaComponents() throws {
        let material = try beyerMaterial()
        let seconda = try #require(material.components.first { $0.role == .seconda })
        let prima = try #require(material.components.first { $0.role == .prima })

        #expect(material.components.count == 2)
        #expect(seconda.title == "Seconda")
        #expect(prima.title == "Prima")
        #expect(seconda.requiredForCompleteExercise)
        #expect(prima.requiredForCompleteExercise)
    }

    @Test func beyerPageLocatorsDistinguishPDFKitIndicesFromPrintedPageLabels() throws {
        let material = try beyerMaterial()
        let seconda = try #require(material.components.first { $0.role == .seconda })
        let prima = try #require(material.components.first { $0.role == .prima })

        #expect(seconda.pdfPageLocator?.documentDescriptorID == PianovoReferenceMaterialCatalogue.beyerScanDocumentID)
        #expect(seconda.pdfPageLocator?.pdfKitPageIndex == 45)
        #expect(seconda.pdfPageLocator?.printedPageLabel == "46")
        #expect(prima.pdfPageLocator?.documentDescriptorID == PianovoReferenceMaterialCatalogue.beyerScanDocumentID)
        #expect(prima.pdfPageLocator?.pdfKitPageIndex == 46)
        #expect(prima.pdfPageLocator?.printedPageLabel == "47")
    }

    @Test func beyerCropRectanglesRemainDeferred() throws {
        let material = try beyerMaterial()

        #expect(material.components.allSatisfy { $0.pdfExcerptHint?.exactCropDeferred == true })
    }

    @Test func catalogueEntryMayExistWithoutExerciseSourceMapping() throws {
        let catalogue = PianovoReferenceMaterialCatalogue.catalogue()
        let arpeggioID = try #require(ReferenceMaterialID("major-arpeggios-2-octaves"))
        let arpeggio = try #require(catalogue.material(withID: arpeggioID))

        #expect(arpeggio.title == "Major Arpeggios 2 Octaves")
        #expect(!PianovoReferenceMaterialCatalogue.sourceMappings.values.contains(arpeggioID))
    }

    @Test func laterBeyerSequenceSourceIsNotMappedToANumberedExerciseMaterial() throws {
        let currentSequenceSource = try #require(ExerciseSourceID("beyer-op101-current-sequence"))

        #expect(PianovoReferenceMaterialCatalogue.sourceMappings[currentSequenceSource] == nil)
    }

    @Test func productionCatalogueDoesNotContainDevelopmentMachinePath() throws {
        let data = try JSONEncoder().encode(PianovoReferenceMaterialCatalogue.catalogue())
        let encoded = try #require(String(data: data, encoding: .utf8))

        #expect(!encoded.contains("/Users/fredericinthavanh"))
        #expect(!encoded.contains("Documents/Xcode Projects/Sightlink Piano/Reference Materials"))
    }

    @Test func unverifiedLicensingStatusRemainsExplicitlyUnknown() {
        let catalogue = PianovoReferenceMaterialCatalogue.catalogue()

        #expect(catalogue.materials.allSatisfy { $0.rightsStatus == .unknown })
    }

    @Test func catalogueTypesRoundTripThroughCodable() throws {
        let catalogue = PianovoReferenceMaterialCatalogue.catalogue()
        let data = try JSONEncoder().encode(catalogue)
        let decoded = try JSONDecoder().decode(ReferenceMaterialCatalogue.self, from: data)

        #expect(decoded == catalogue)
    }

    @Test func stableIDInitializersRejectEmptyValues() {
        #expect(ReferenceMaterialID("") == nil)
        #expect(ReferenceMaterialComponentID(" \n ") == nil)
        #expect(ReferenceDocumentDescriptorID("") == nil)
        #expect(DocumentAccessReference("") == nil)
    }

    private func beyerMaterial() throws -> ReferenceMaterial {
        try #require(PianovoReferenceMaterialCatalogue.catalogue().material(withID: PianovoReferenceMaterialCatalogue.beyerNo63ID))
    }
}

private struct AvailableDocumentProvider: DocumentAvailabilityProviding {
    func availability(for material: ReferenceMaterial) -> DocumentAvailability {
        .available(DocumentAccessReference("test-document-token")!)
    }
}
