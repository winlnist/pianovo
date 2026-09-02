import Foundation

protocol DocumentAvailabilityProviding {
    func availability(for material: ReferenceMaterial) -> DocumentAvailability
}

protocol ReferenceMaterialResolving {
    func resolve(sourceID: ExerciseSourceID) -> ReferenceMaterialResolution
}

nonisolated struct DefaultUnavailableDocumentAvailabilityProvider: DocumentAvailabilityProviding {
    func availability(for material: ReferenceMaterial) -> DocumentAvailability {
        .unavailable(reason: .notImported)
    }
}

nonisolated struct ReferenceMaterialResolver: ReferenceMaterialResolving {
    let catalogue: ReferenceMaterialCatalogue
    let sourceMappings: [ExerciseSourceID: ReferenceMaterialID]
    let availabilityProvider: any DocumentAvailabilityProviding

    init(
        catalogue: ReferenceMaterialCatalogue,
        sourceMappings: [ExerciseSourceID: ReferenceMaterialID],
        availabilityProvider: any DocumentAvailabilityProviding = DefaultUnavailableDocumentAvailabilityProvider()
    ) {
        self.catalogue = catalogue
        self.sourceMappings = sourceMappings
        self.availabilityProvider = availabilityProvider
    }

    func resolve(sourceID: ExerciseSourceID) -> ReferenceMaterialResolution {
        guard let materialID = sourceMappings[sourceID] else {
            return ReferenceMaterialResolution(
                sourceID: sourceID,
                material: nil,
                availability: nil,
                issue: .unknownSource(sourceID)
            )
        }

        guard let material = catalogue.material(withID: materialID) else {
            return ReferenceMaterialResolution(
                sourceID: sourceID,
                material: nil,
                availability: nil,
                issue: .unknownMaterial(materialID)
            )
        }

        let availability = availabilityProvider.availability(for: material)
        return ReferenceMaterialResolution(
            sourceID: sourceID,
            material: material,
            availability: availability,
            issue: availability.issue
        )
    }
}

nonisolated struct ReferenceMaterialResolution: Hashable {
    let sourceID: ExerciseSourceID
    let material: ReferenceMaterial?
    let availability: DocumentAvailability?
    let issue: ReferenceMaterialResolutionIssue?
}

nonisolated enum ReferenceMaterialResolutionIssue: Hashable {
    case unknownSource(ExerciseSourceID)
    case unknownMaterial(ReferenceMaterialID)
    case unavailable(DocumentUnavailableReason)
}

private extension DocumentAvailability {
    var issue: ReferenceMaterialResolutionIssue? {
        switch self {
        case .available:
            nil
        case .unavailable(let reason):
            .unavailable(reason)
        }
    }
}
