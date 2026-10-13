import Foundation

nonisolated struct LibraryTemplateID: Codable, Hashable { let rawValue: UUID }
nonisolated struct LibraryTemplateRevisionID: Codable, Hashable { let rawValue: UUID }

nonisolated struct LibraryTemplateDraft: Equatable, Codable {
    var name = ""
    var defaults = LibraryExerciseDraft()
    var normalised: Self {
        Self(name: name.trimmingCharacters(in: .whitespacesAndNewlines), defaults: defaults.normalised)
    }
    var validationIssues: [LibraryValidationIssue] {
        (normalised.name.isEmpty ? [.templateNameRequired] : []) + defaults.validationIssues
    }
}

nonisolated struct LibraryExerciseTemplateRevision: Identifiable, Equatable, Codable {
    let id: LibraryTemplateRevisionID
    let templateID: LibraryTemplateID
    let parentRevisionID: LibraryTemplateRevisionID?
    let content: LibraryTemplateDraft
    let createdAt: Date
    let starterPattern: LibraryStarterPattern?
}

nonisolated struct LibraryExerciseTemplate: Identifiable, Equatable {
    let id: LibraryTemplateID
    let ownerID: LibraryOwnerID
    let currentRevision: LibraryExerciseTemplateRevision
    let isArchived: Bool
}

nonisolated struct LibraryTemplateOrigin: Codable, Equatable {
    let templateID: LibraryTemplateID
    let revisionID: LibraryTemplateRevisionID
    let name: String
    let creatorAttribution: String?

    init(_ revision: LibraryExerciseTemplateRevision) {
        templateID = revision.templateID
        revisionID = revision.id
        name = revision.content.name
        creatorAttribution = revision.starterPattern == nil ? nil : "Pianovo starter pattern"
    }
}

nonisolated enum LibraryStarterPattern: String, Codable, CaseIterable {
    case relaxedWarmUpV1, sightReadingGuidanceV1, reflectionV1

    var draft: LibraryTemplateDraft {
        switch self {
        case .relaxedWarmUpV1:
            LibraryTemplateDraft(name: "Relaxed warm-up", defaults: LibraryExerciseDraft(title: "Relaxed warm-up",
                category: .warmUp, instructions: "Choose a familiar scale or movement. Practise slowly with relaxed hands and listen for an even tone.",
                learningPurpose: "Prepare comfortable, controlled movement.", referenceMaterialID: nil))
        case .sightReadingGuidanceV1:
            LibraryTemplateDraft(name: "Sight-reading guidance", defaults: LibraryExerciseDraft(title: "Sight-reading preparation",
                category: .sightReading, instructions: "Choose an appropriate passage from material you can access. Identify the clef and range, then read at a comfortable pace. Adapt these instructions to your chosen material.",
                learningPurpose: "Build deliberate note-reading habits.", referenceMaterialID: nil))
        case .reflectionV1:
            LibraryTemplateDraft(name: "Practice reflection", defaults: LibraryExerciseDraft(title: "Reflect on practice",
                category: .reflection, instructions: "Review what felt comfortable and what needs another attempt. Decide one focus for your next practice session.",
                learningPurpose: "Choose a useful next practice focus.", referenceMaterialID: nil))
        }
    }
}

nonisolated enum LibraryTemplateMutation: Equatable {
    case create(LibraryExerciseTemplateRevision)
    case revise(LibraryExerciseTemplateRevision, replacing: LibraryTemplateRevisionID)
    case setArchived(LibraryTemplateID, expectedRevision: LibraryTemplateRevisionID, archived: Bool)

    var templateID: LibraryTemplateID {
        switch self {
        case .create(let revision), .revise(let revision, _): revision.templateID
        case .setArchived(let id, _, _): id
        }
    }
    var revision: LibraryExerciseTemplateRevision? {
        switch self {
        case .create(let revision), .revise(let revision, _): revision
        case .setArchived: nil
        }
    }
    func applying(to existing: LibraryExerciseTemplate?, history: [LibraryExerciseTemplateRevision], ownerID: LibraryOwnerID) throws -> LibraryExerciseTemplate {
        if let revision {
            guard revision.content.validationIssues.isEmpty else { throw LibraryRepositoryError.invalid(revision.content.validationIssues) }
            guard revision.createdAt.timeIntervalSince1970.isFinite else { throw LibraryRepositoryError.corruptStore }
        }
        switch self {
        case .create(let revision):
            guard revision.parentRevisionID == nil else { throw LibraryRepositoryError.conflict }
            if let existing {
                guard existing.currentRevision == revision else { throw LibraryRepositoryError.duplicateID }
                return existing
            }
            guard history.isEmpty else { throw LibraryRepositoryError.duplicateID }
            return LibraryExerciseTemplate(id: revision.templateID, ownerID: ownerID, currentRevision: revision, isArchived: false)
        case .revise(let revision, let expected):
            guard let existing else { throw LibraryRepositoryError.notFound }
            if let prior = history.first(where: { $0.id == revision.id }) {
                guard prior == revision, existing.currentRevision == revision else { throw LibraryRepositoryError.conflict }
                return existing
            }
            guard !existing.isArchived else { throw LibraryRepositoryError.archived }
            guard existing.currentRevision.id == expected, revision.parentRevisionID == expected,
                  revision.starterPattern == existing.currentRevision.starterPattern else { throw LibraryRepositoryError.conflict }
            return LibraryExerciseTemplate(id: existing.id, ownerID: existing.ownerID, currentRevision: revision, isArchived: false)
        case .setArchived(_, let expected, let archived):
            guard let existing else { throw LibraryRepositoryError.notFound }
            guard existing.currentRevision.id == expected else { throw LibraryRepositoryError.conflict }
            return LibraryExerciseTemplate(id: existing.id, ownerID: existing.ownerID, currentRevision: existing.currentRevision, isArchived: archived)
        }
    }
}

@MainActor
protocol LibraryExerciseTemplateRepository {
    func templates() async throws -> [LibraryExerciseTemplate]
    func revisionHistory(for id: LibraryTemplateID) async throws -> [LibraryExerciseTemplateRevision]
    func apply(_ mutation: LibraryTemplateMutation) async throws -> LibraryExerciseTemplate
}

@MainActor
final class InMemoryLibraryExerciseTemplateRepository: LibraryExerciseTemplateRepository {
    private let ownerID: LibraryOwnerID
    private var values: [LibraryTemplateID: LibraryExerciseTemplate] = [:]
    private var revisions: [LibraryTemplateID: [LibraryExerciseTemplateRevision]] = [:]
    init(ownerID: LibraryOwnerID = LibraryOwnerID(rawValue: UUID())) { self.ownerID = ownerID }
    func templates() async throws -> [LibraryExerciseTemplate] { Array(values.values) }
    func revisionHistory(for id: LibraryTemplateID) async throws -> [LibraryExerciseTemplateRevision] {
        guard let history = revisions[id] else { throw LibraryRepositoryError.notFound }
        return history
    }
    func apply(_ mutation: LibraryTemplateMutation) async throws -> LibraryExerciseTemplate {
        if let revision = mutation.revision, revisions.values.flatMap({ $0 }).contains(where: { $0.id == revision.id && $0.templateID != revision.templateID }) {
            throw LibraryRepositoryError.duplicateID
        }
        let result = try mutation.applying(to: values[mutation.templateID], history: revisions[mutation.templateID] ?? [], ownerID: ownerID)
        if let revision = mutation.revision, !(revisions[mutation.templateID] ?? []).contains(revision) {
            revisions[mutation.templateID, default: []].append(revision)
        }
        values[result.id] = result
        return result
    }
}
