import Foundation

nonisolated struct LibraryExerciseID: Codable, Hashable { let rawValue: UUID }
nonisolated struct LibraryRevisionID: Codable, Hashable { let rawValue: UUID }
nonisolated struct LibraryOwnerID: Codable, Hashable { let rawValue: UUID }

nonisolated enum LibraryExerciseCategory: String, Codable, CaseIterable {
    case warmUp, technique, beyer, repertoireHarmony, sightReading, review, reflection
}

nonisolated struct LibraryExerciseDraft: Equatable, Codable {
    var title = ""
    var category: LibraryExerciseCategory = .warmUp
    var instructions = ""
    var learningPurpose = ""
    var referenceMaterialID: ReferenceMaterialID?

    var normalised: Self {
        var value = self
        value.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        value.learningPurpose = learningPurpose.trimmingCharacters(in: .whitespacesAndNewlines)
        return value
    }

    var validationIssues: [LibraryValidationIssue] {
        let value = normalised
        var issues: [LibraryValidationIssue] = []
        if value.title.isEmpty { issues.append(.titleRequired) }
        if value.instructions.isEmpty { issues.append(.instructionsRequired) }
        if value.learningPurpose.isEmpty { issues.append(.purposeRequired) }
        return issues
    }
}

nonisolated enum LibraryValidationIssue: Equatable { case titleRequired, instructionsRequired, purposeRequired, templateNameRequired }

nonisolated struct LibraryExerciseOrigin: Equatable, Codable {
    let exerciseID: LibraryExerciseID
    let revisionID: LibraryRevisionID
    let creatorAttribution: String?
}

nonisolated struct LibraryExerciseRevision: Equatable, Codable, Identifiable {
    let id: LibraryRevisionID
    let exerciseID: LibraryExerciseID
    let parentRevisionID: LibraryRevisionID?
    let content: LibraryExerciseDraft
    let createdAt: Date
    let origin: LibraryExerciseOrigin?
    let templateOrigin: LibraryTemplateOrigin?

    init(id: LibraryRevisionID, exerciseID: LibraryExerciseID, parentRevisionID: LibraryRevisionID?,
         content: LibraryExerciseDraft, createdAt: Date, origin: LibraryExerciseOrigin?, templateOrigin: LibraryTemplateOrigin? = nil) {
        self.id = id
        self.exerciseID = exerciseID
        self.parentRevisionID = parentRevisionID
        self.content = content
        self.createdAt = createdAt
        self.origin = origin
        self.templateOrigin = templateOrigin
    }
}

nonisolated struct LibraryExercise: Equatable, Identifiable {
    let id: LibraryExerciseID
    let ownerID: LibraryOwnerID
    let currentRevision: LibraryExerciseRevision
    let isArchived: Bool
}

nonisolated enum LibraryRepositoryError: Error, Equatable {
    case invalid([LibraryValidationIssue])
    case notFound, conflict, duplicateID, archived, corruptStore, verificationFailed
}

nonisolated enum LibraryMutation: Equatable {
    case create(LibraryExerciseRevision)
    case revise(LibraryExerciseRevision, replacing: LibraryRevisionID)
    case setArchived(LibraryExerciseID, expectedRevision: LibraryRevisionID, archived: Bool)

    var exerciseID: LibraryExerciseID {
        switch self {
        case .create(let revision), .revise(let revision, _): revision.exerciseID
        case .setArchived(let id, _, _): id
        }
    }

    var revision: LibraryExerciseRevision? {
        switch self {
        case .create(let revision), .revise(let revision, _): revision
        case .setArchived: nil
        }
    }

    /// Pure rules shared by local storage and deterministic in-memory previews.
    func applying(to existing: LibraryExercise?, history: [LibraryExerciseRevision],
                  ownerID: LibraryOwnerID) throws -> LibraryExercise {
        if let revision {
            let issues = revision.content.validationIssues
            guard issues.isEmpty else { throw LibraryRepositoryError.invalid(issues) }
            guard revision.createdAt.timeIntervalSince1970.isFinite else { throw LibraryRepositoryError.corruptStore }
        }
        switch self {
        case .create(let revision):
            guard revision.parentRevisionID == nil else { throw LibraryRepositoryError.conflict }
            if let existing {
                guard existing.currentRevision == revision else { throw LibraryRepositoryError.duplicateID }
                return existing // Retrying a create that already reached storage never creates another exercise.
            }
            guard history.isEmpty else { throw LibraryRepositoryError.duplicateID }
            return LibraryExercise(id: revision.exerciseID, ownerID: ownerID, currentRevision: revision, isArchived: false)
        case .revise(let revision, let expected):
            guard let existing else { throw LibraryRepositoryError.notFound }
            if let prior = history.first(where: { $0.id == revision.id }) {
                guard prior == revision, existing.currentRevision == revision else { throw LibraryRepositoryError.conflict }
                return existing
            }
            guard !existing.isArchived else { throw LibraryRepositoryError.archived }
            guard existing.currentRevision.id == expected, revision.parentRevisionID == expected else {
                throw LibraryRepositoryError.conflict
            }
            guard revision.origin == existing.currentRevision.origin, revision.templateOrigin == existing.currentRevision.templateOrigin else { throw LibraryRepositoryError.conflict }
            return LibraryExercise(id: existing.id, ownerID: existing.ownerID, currentRevision: revision, isArchived: false)
        case .setArchived(_, let expected, let archived):
            guard let existing else { throw LibraryRepositoryError.notFound }
            guard existing.currentRevision.id == expected else { throw LibraryRepositoryError.conflict }
            return LibraryExercise(id: existing.id, ownerID: existing.ownerID,
                                   currentRevision: existing.currentRevision, isArchived: archived)
        }
    }
}
