import Foundation
import SwiftData

@MainActor
final class SwiftDataLibraryProgrammeRepository: LibraryProgrammeTemplateRepository {
    private let container: ModelContainer
    private let save: (ModelContext) throws -> Void
    private let makeOwnerID: () -> LibraryOwnerID
    init(container: ModelContainer, save: @escaping (ModelContext) throws -> Void = { try $0.save() },
         makeOwnerID: @escaping () -> LibraryOwnerID = { LibraryOwnerID(rawValue: UUID()) }) {
        self.container = container
        self.save = save
        self.makeOwnerID = makeOwnerID
    }
    func templates() async throws -> [LibraryProgrammeTemplate] {
        let reader = ModelContext(container)
        return try reader.fetch(FetchDescriptor<LibrarySchemaV3.ProgrammeModel>()).map { try template($0, in: reader) }
    }
    func revisionHistory(for id: LibraryProgrammeTemplateID) async throws -> [LibraryProgrammeTemplateRevision] {
        let reader = ModelContext(container)
        guard let model = try reader.fetch(FetchDescriptor<LibrarySchemaV3.ProgrammeModel>()).first(where: { $0.id == id.rawValue }) else {
            throw LibraryRepositoryError.notFound
        }
        return try history(model, in: reader)
    }
    func apply(_ mutation: LibraryProgrammeMutation) async throws -> LibraryProgrammeTemplate {
        let writer = ModelContext(container)
        writer.autosaveEnabled = false
        do {
            let model = try writer.fetch(FetchDescriptor<LibrarySchemaV3.ProgrammeModel>()).first { $0.id == mutation.templateID.rawValue }
            let existing = try model.map { try template($0, in: writer) }
            let revisions = try model.map { try history($0, in: writer) } ?? []
            let identity = try writer.fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).first { $0.key == "local-owner" }
            if let model, model.ownerID != identity?.ownerID { throw LibraryRepositoryError.corruptStore }
            let ownerID = identity.map { LibraryOwnerID(rawValue: $0.ownerID) } ?? makeOwnerID()
            if let revision = mutation.revision { try validateReferences(revision.content.references, in: writer) }
            let result = try mutation.applying(to: existing, history: revisions, ownerID: ownerID)
            if let revision = mutation.revision {
                let all = try writer.fetch(FetchDescriptor<LibrarySchemaV3.ProgrammeRevisionModel>())
                if let prior = all.first(where: { $0.id == revision.id.rawValue }) {
                    guard try decode(prior) == revision else { throw LibraryRepositoryError.duplicateID }
                } else { writer.insert(try LibrarySchemaV3.ProgrammeRevisionModel(revision)) }
            }
            if result == existing { return result }
            if identity == nil { writer.insert(LibrarySchemaV1.IdentityModel(ownerID: ownerID)) }
            if let model {
                model.currentRevisionID = result.currentRevision.id.rawValue
                model.isArchived = result.isArchived
            } else { writer.insert(LibrarySchemaV3.ProgrammeModel(result)) }
            try save(writer)
            let reader = ModelContext(container)
            guard let durable = try reader.fetch(FetchDescriptor<LibrarySchemaV3.ProgrammeModel>()).first(where: { $0.id == result.id.rawValue }),
                  try template(durable, in: reader) == result else { throw LibraryRepositoryError.verificationFailed }
            return result
        } catch { writer.rollback(); throw error }
    }
    private func validateReferences(_ references: Set<LibraryExerciseReference>, in context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor<LibrarySchemaV1.RevisionModel>())
        let heads = try context.fetch(FetchDescriptor<LibrarySchemaV1.ExerciseModel>())
        for reference in references {
            guard heads.contains(where: { $0.id == reference.exerciseID.rawValue }),
                  let row = rows.first(where: { $0.id == reference.revisionID.rawValue && $0.exerciseID == reference.exerciseID.rawValue }),
                  let revision = try? JSONDecoder().decode(LibraryExerciseRevision.self, from: row.payload),
                  revision.id == reference.revisionID, revision.exerciseID == reference.exerciseID,
                  revision.content.validationIssues.isEmpty else { throw LibraryProgrammeError.missingExerciseRevision }
        }
    }
    private func template(_ model: LibrarySchemaV3.ProgrammeModel, in context: ModelContext) throws -> LibraryProgrammeTemplate {
        let revisions = try history(model, in: context)
        guard let current = revisions.last,
              let identity = try context.fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).first(where: { $0.key == "local-owner" }),
              model.ownerID == identity.ownerID else { throw LibraryRepositoryError.corruptStore }
        return LibraryProgrammeTemplate(id: LibraryProgrammeTemplateID(rawValue: model.id), ownerID: LibraryOwnerID(rawValue: model.ownerID),
                                       currentRevision: current, isArchived: model.isArchived)
    }
    private func history(_ model: LibrarySchemaV3.ProgrammeModel, in context: ModelContext) throws -> [LibraryProgrammeTemplateRevision] {
        let revisions = try context.fetch(FetchDescriptor<LibrarySchemaV3.ProgrammeRevisionModel>()).filter { $0.templateID == model.id }.map(decode)
        var ordered: [LibraryProgrammeTemplateRevision] = []
        var current: LibraryProgrammeRevisionID? = LibraryProgrammeRevisionID(rawValue: model.currentRevisionID)
        var visited: Set<LibraryProgrammeRevisionID> = []
        while let id = current {
            guard visited.insert(id).inserted, let revision = revisions.first(where: { $0.id == id }) else { throw LibraryRepositoryError.corruptStore }
            ordered.append(revision)
            current = revision.parentRevisionID
        }
        guard !ordered.isEmpty, ordered.count == revisions.count else { throw LibraryRepositoryError.corruptStore }
        return ordered.reversed()
    }
    private func decode(_ model: LibrarySchemaV3.ProgrammeRevisionModel) throws -> LibraryProgrammeTemplateRevision {
        guard let value = try? JSONDecoder().decode(LibraryProgrammeTemplateRevision.self, from: model.payload),
              value.id.rawValue == model.id, value.templateID.rawValue == model.templateID,
              value.content.validationIssues.isEmpty, value.createdAt.timeIntervalSince1970.isFinite else {
            throw LibraryRepositoryError.corruptStore
        }
        return value
    }
}
