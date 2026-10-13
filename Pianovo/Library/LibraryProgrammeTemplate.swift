import Foundation

nonisolated struct LibraryProgrammeTemplateID: Codable, Hashable { let rawValue: UUID }
nonisolated struct LibraryProgrammeRevisionID: Codable, Hashable { let rawValue: UUID }

nonisolated struct LibraryExerciseReference: Equatable, Codable, Hashable {
    let exerciseID: LibraryExerciseID
    let revisionID: LibraryRevisionID
}

nonisolated struct LibraryProgrammePlacement: Identifiable, Equatable, Codable {
    let id: UUID
    var exercise: LibraryExerciseReference
    var goal: String
    var minutes: Int
}
nonisolated struct LibraryProgrammeSection: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var placements: [LibraryProgrammePlacement] = []
}
nonisolated struct LibraryProgrammeDay: Identifiable, Equatable, Codable {
    let id: UUID
    var isRecovery = false
    var sections: [LibraryProgrammeSection] = []
}
nonisolated struct LibraryProgrammeWeek: Identifiable, Equatable, Codable {
    let id: UUID
    var days: [LibraryProgrammeDay] = []
}
nonisolated enum LibraryProgrammeIssue: Equatable {
    case nameRequired, invalidShape, duplicateIdentity, sectionNameRequired, goalRequired, invalidDuration
    var message: String {
        switch self {
        case .nameRequired: "Give the programme template a name."
        case .invalidShape: "Use 1–104 weeks, 1–7 days per week, up to 8 sections per day and 100 exercises per section."
        case .duplicateIdentity: "Each week, day, section and exercise placement needs a distinct identity."
        case .sectionNameRequired: "Give every section a name."
        case .goalRequired: "Give each exercise placement a goal."
        case .invalidDuration: "Use a planned duration of 1–1440 minutes per exercise."
        }
    }
}
nonisolated enum LibraryProgrammeError: Error, Equatable {
    case invalid([LibraryProgrammeIssue]), missingExerciseRevision
}

nonisolated struct LibraryProgrammeDraft: Equatable, Codable {
    var name = ""
    var weeks: [LibraryProgrammeWeek] = []
    var normalised: Self {
        var result = self
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        for w in result.weeks.indices {
            for d in result.weeks[w].days.indices {
                for s in result.weeks[w].days[d].sections.indices {
                    result.weeks[w].days[d].sections[s].name = result.weeks[w].days[d].sections[s].name.trimmingCharacters(in: .whitespacesAndNewlines)
                    for a in result.weeks[w].days[d].sections[s].placements.indices {
                        result.weeks[w].days[d].sections[s].placements[a].goal = result.weeks[w].days[d].sections[s].placements[a].goal.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        return result
    }
    var structuralIDs: Set<UUID> {
        let days = weeks.flatMap(\.days)
        let sections = days.flatMap(\.sections)
        return Set(weeks.map(\.id) + days.map(\.id) + sections.map(\.id) + sections.flatMap(\.placements).map(\.id))
    }
    var references: Set<LibraryExerciseReference> {
        Set(weeks.flatMap(\.days).flatMap(\.sections).flatMap(\.placements).map(\.exercise))
    }
    var validationIssues: [LibraryProgrammeIssue] {
        let value = normalised
        var issues: [LibraryProgrammeIssue] = []
        if value.name.isEmpty { issues.append(.nameRequired) }
        if !(1...104).contains(weeks.count) || weeks.contains(where: { !(1...7).contains($0.days.count) }) ||
            weeks.flatMap(\.days).contains(where: { $0.sections.count > 8 }) ||
            weeks.flatMap(\.days).flatMap(\.sections).contains(where: { $0.placements.count > 100 }) { issues.append(.invalidShape) }
        let days = value.weeks.flatMap(\.days)
        let sections = days.flatMap(\.sections)
        let placements = sections.flatMap(\.placements)
        let ids = weeks.map(\.id) + days.map(\.id) + sections.map(\.id) + placements.map(\.id)
        if Set(ids).count != ids.count { issues.append(.duplicateIdentity) }
        if sections.contains(where: { $0.name.isEmpty }) { issues.append(.sectionNameRequired) }
        if placements.contains(where: { $0.goal.isEmpty }) { issues.append(.goalRequired) }
        if placements.contains(where: { !(1...1440).contains($0.minutes) }) { issues.append(.invalidDuration) }
        return issues
    }
    /// A template copy is independent. Exercise references stay pinned; structural identities do not.
    func independentCopy(makeUUID: () -> UUID = UUID.init) -> Self {
        Self(name: name + " copy", weeks: weeks.map { week in
            LibraryProgrammeWeek(id: makeUUID(), days: week.days.map { day in
                LibraryProgrammeDay(id: makeUUID(), isRecovery: day.isRecovery, sections: day.sections.map { section in
                    LibraryProgrammeSection(id: makeUUID(), name: section.name, placements: section.placements.map { placement in
                        LibraryProgrammePlacement(id: makeUUID(), exercise: placement.exercise, goal: placement.goal, minutes: placement.minutes)
                    })
                })
            })
        })
    }
    static func starter(weekCount: Int, makeUUID: () -> UUID = UUID.init) -> Self {
        Self(weeks: (0..<min(104, max(1, weekCount))).map { _ in
            LibraryProgrammeWeek(id: makeUUID(), days: (0..<7).map { day in
                LibraryProgrammeDay(id: makeUUID(), isRecovery: day == 6, sections: day == 6 ? [] : [
                    LibraryProgrammeSection(id: makeUUID(), name: "Morning"),
                    LibraryProgrammeSection(id: makeUUID(), name: "Evening")
                ])
            })
        })
    }
}
nonisolated struct LibraryProgrammeOrigin: Equatable, Codable {
    let templateID: LibraryProgrammeTemplateID
    let revisionID: LibraryProgrammeRevisionID
    let name: String
    let creatorAttribution: String?
}
nonisolated struct LibraryProgrammeTemplateRevision: Equatable, Codable, Identifiable {
    let id: LibraryProgrammeRevisionID
    let templateID: LibraryProgrammeTemplateID
    let parentRevisionID: LibraryProgrammeRevisionID?
    let content: LibraryProgrammeDraft
    let createdAt: Date
    let origin: LibraryProgrammeOrigin?
}
nonisolated struct LibraryProgrammeTemplate: Equatable, Identifiable {
    let id: LibraryProgrammeTemplateID
    let ownerID: LibraryOwnerID
    let currentRevision: LibraryProgrammeTemplateRevision
    let isArchived: Bool
}

nonisolated enum LibraryProgrammeMutation: Equatable {
    case create(LibraryProgrammeTemplateRevision)
    case revise(LibraryProgrammeTemplateRevision, replacing: LibraryProgrammeRevisionID)
    case setArchived(LibraryProgrammeTemplateID, expectedRevision: LibraryProgrammeRevisionID, archived: Bool)

    var templateID: LibraryProgrammeTemplateID {
        switch self {
        case .create(let revision), .revise(let revision, _): revision.templateID
        case .setArchived(let id, _, _): id
        }
    }
    var revision: LibraryProgrammeTemplateRevision? {
        switch self {
        case .create(let revision), .revise(let revision, _): revision
        case .setArchived: nil
        }
    }
    func applying(to existing: LibraryProgrammeTemplate?, history: [LibraryProgrammeTemplateRevision], ownerID: LibraryOwnerID) throws -> LibraryProgrammeTemplate {
        if let revision {
            guard revision.content.validationIssues.isEmpty else { throw LibraryProgrammeError.invalid(revision.content.validationIssues) }
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
            return LibraryProgrammeTemplate(id: revision.templateID, ownerID: ownerID, currentRevision: revision, isArchived: false)
        case .revise(let revision, let expected):
            guard let existing else { throw LibraryRepositoryError.notFound }
            if let prior = history.first(where: { $0.id == revision.id }) {
                guard prior == revision, existing.currentRevision == revision else { throw LibraryRepositoryError.conflict }
                return existing
            }
            guard !existing.isArchived else { throw LibraryRepositoryError.archived }
            guard existing.currentRevision.id == expected, revision.parentRevisionID == expected,
                  revision.origin == existing.currentRevision.origin else { throw LibraryRepositoryError.conflict }
            return LibraryProgrammeTemplate(id: existing.id, ownerID: existing.ownerID, currentRevision: revision, isArchived: false)
        case .setArchived(_, let expected, let archived):
            guard let existing else { throw LibraryRepositoryError.notFound }
            guard existing.currentRevision.id == expected else { throw LibraryRepositoryError.conflict }
            return LibraryProgrammeTemplate(id: existing.id, ownerID: existing.ownerID, currentRevision: existing.currentRevision, isArchived: archived)
        }
    }
}

@MainActor
protocol LibraryProgrammeTemplateRepository {
    func templates() async throws -> [LibraryProgrammeTemplate]
    func revisionHistory(for id: LibraryProgrammeTemplateID) async throws -> [LibraryProgrammeTemplateRevision]
    func apply(_ mutation: LibraryProgrammeMutation) async throws -> LibraryProgrammeTemplate
}

@MainActor
final class InMemoryLibraryProgrammeTemplateRepository: LibraryProgrammeTemplateRepository {
    private let ownerID: LibraryOwnerID
    private let exerciseRepository: (any LibraryExerciseRepository)?
    private var values: [LibraryProgrammeTemplateID: LibraryProgrammeTemplate] = [:]
    private var revisions: [LibraryProgrammeTemplateID: [LibraryProgrammeTemplateRevision]] = [:]
    init(ownerID: LibraryOwnerID = LibraryOwnerID(rawValue: UUID()), exerciseRepository: (any LibraryExerciseRepository)? = nil) {
        self.ownerID = ownerID; self.exerciseRepository = exerciseRepository
    }
    func templates() async throws -> [LibraryProgrammeTemplate] { Array(values.values) }
    func revisionHistory(for id: LibraryProgrammeTemplateID) async throws -> [LibraryProgrammeTemplateRevision] {
        guard let history = revisions[id] else { throw LibraryRepositoryError.notFound }
        return history
    }
    func apply(_ mutation: LibraryProgrammeMutation) async throws -> LibraryProgrammeTemplate {
        if let revision = mutation.revision, revisions.values.flatMap({ $0 }).contains(where: { $0.id == revision.id && $0.templateID != revision.templateID }) {
            throw LibraryRepositoryError.duplicateID
        }
        if let revision = mutation.revision {
            for reference in revision.content.references {
                guard let exerciseRepository else { throw LibraryProgrammeError.missingExerciseRevision }
                let history = try await exerciseRepository.revisionHistory(for: reference.exerciseID)
                guard history.contains(where: { $0.id == reference.revisionID && $0.exerciseID == reference.exerciseID }) else {
                    throw LibraryProgrammeError.missingExerciseRevision
                }
            }
        }
        let result = try mutation.applying(to: values[mutation.templateID], history: revisions[mutation.templateID] ?? [], ownerID: ownerID)
        if let revision = mutation.revision, !(revisions[mutation.templateID] ?? []).contains(revision) {
            revisions[mutation.templateID, default: []].append(revision)
        }
        values[result.id] = result
        return result
    }
}
