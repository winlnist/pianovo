import Foundation

nonisolated struct ReferenceMaterialID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        self.rawValue = trimmed
    }
}

nonisolated struct ReferenceMaterialComponentID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        self.rawValue = trimmed
    }
}

nonisolated struct ReferenceDocumentDescriptorID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        self.rawValue = trimmed
    }
}

nonisolated struct ReferenceMaterialCatalogue: Codable, Hashable {
    let materials: [ReferenceMaterial]

    func material(withID id: ReferenceMaterialID) -> ReferenceMaterial? {
        materials.first { $0.id == id }
    }
}

nonisolated struct ReferenceMaterial: Identifiable, Codable, Hashable {
    let id: ReferenceMaterialID
    let title: String
    let kind: ReferenceMaterialKind
    let formats: [ReferenceMaterialFormat]
    let languages: [ReferenceMaterialLanguage]
    let documentDescriptors: [ReferenceDocumentDescriptor]
    let components: [ReferenceMaterialComponent]
    let attribution: ReferenceMaterialAttribution?
    let rightsStatus: ReferenceMaterialRightsStatus
    let accessRequirement: DocumentAccessRequirement
    let programmeUseHint: String?
}

nonisolated enum ReferenceMaterialKind: String, Codable, Hashable {
    case beyerExercise
    case scale
    case arpeggio
    case chordProgression
    case chordInversion
    case jazzHarmony
    case audioCompanion
}

nonisolated enum ReferenceMaterialFormat: String, Codable, Hashable {
    case pdf
    case audio
}

nonisolated enum ReferenceMaterialLanguage: String, Codable, Hashable {
    case english
    case french
    case german
}

nonisolated enum ReferenceMaterialRightsStatus: String, Codable, Hashable {
    case unknown
    case permissionKnown
    case publicDomainVerified
    case restricted
}

nonisolated enum DocumentAccessRequirement: String, Codable, Hashable {
    case userProvidedDocument
    case securityScopedDocumentReference
    case appManagedLocalCopy
    case legallyApprovedBundledResource
}

nonisolated struct ReferenceMaterialAttribution: Codable, Hashable {
    let edition: String?
    let creator: String?
    let producer: String?
    let visibleCredit: String?
}

nonisolated struct ReferenceDocumentDescriptor: Identifiable, Codable, Hashable {
    let id: ReferenceDocumentDescriptorID
    let expectedFilename: String
    let format: ReferenceMaterialFormat
    let pageCount: Int?
    let audioDurationSeconds: Double?
    let descriptorNote: String?
}

nonisolated struct ReferenceMaterialComponent: Identifiable, Codable, Hashable {
    let id: ReferenceMaterialComponentID
    let title: String
    let role: ReferenceMaterialComponentRole
    let requiredForCompleteExercise: Bool
    let pdfPageLocator: PDFPageLocator?
    let pdfExcerptHint: PDFExcerptHint?
}

nonisolated enum ReferenceMaterialComponentRole: String, Codable, Hashable {
    case fullDocument
    case pageRange
    case audioTrack
    case seconda
    case prima
}

nonisolated struct PDFPageLocator: Codable, Hashable {
    let documentDescriptorID: ReferenceDocumentDescriptorID
    let pdfKitPageIndex: Int
    let printedPageLabel: String?
}

nonisolated struct PDFExcerptHint: Codable, Hashable {
    let description: String
    let exactCropDeferred: Bool
}

nonisolated enum DocumentAvailability: Codable, Hashable {
    case unavailable(reason: DocumentUnavailableReason)
    case available(DocumentAccessReference)
}

nonisolated enum DocumentUnavailableReason: String, Codable, Hashable {
    case notImported
    case accessNotGranted
    case missing
}

nonisolated struct DocumentAccessReference: Codable, Hashable {
    let token: String

    init?(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        self.token = trimmed
    }
}
