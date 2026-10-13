import Foundation
import SwiftData

@MainActor
final class SwiftDataLibraryTemplateRepository: LibraryExerciseTemplateRepository {
    private let container: ModelContainer
    private let save: (ModelContext) throws -> Void
    private let makeOwnerID: () -> LibraryOwnerID
    init(container: ModelContainer, save: @escaping (ModelContext) throws -> Void = { try $0.save() },
         makeOwnerID: @escaping () -> LibraryOwnerID = { LibraryOwnerID(rawValue: UUID()) }) {
        self.container = container
        self.save = save
        self.makeOwnerID = makeOwnerID
    }
    func templates() async throws -> [LibraryExerciseTemplate] {
        let reader = ModelContext(container)
        return try reader.fetch(FetchDescriptor<LibrarySchemaV2.TemplateModel>()).map { try template($0, in: reader) }
    }
    func revisionHistory(for id: LibraryTemplateID) async throws -> [LibraryExerciseTemplateRevision] {
        let reader = ModelContext(container)
        guard let model = try reader.fetch(FetchDescriptor<LibrarySchemaV2.TemplateModel>()).first(where: { $0.id == id.rawValue }) else {
            throw LibraryRepositoryError.notFound
        }
        return try history(model, in: reader)
    }
    func apply(_ mutation: LibraryTemplateMutation) async throws -> LibraryExerciseTemplate {
        let writer = ModelContext(container)
        writer.autosaveEnabled = false
        do {
            let model = try writer.fetch(FetchDescriptor<LibrarySchemaV2.TemplateModel>()).first { $0.id == mutation.templateID.rawValue }
            let existing = try model.map { try template($0, in: writer) }
            let revisions = try model.map { try history($0, in: writer) } ?? []
            let identity = try writer.fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).first { $0.key == "local-owner" }
            if let model, model.ownerID != identity?.ownerID { throw LibraryRepositoryError.corruptStore }
            let ownerID = identity.map { LibraryOwnerID(rawValue: $0.ownerID) } ?? makeOwnerID()
            let result = try mutation.applying(to: existing, history: revisions, ownerID: ownerID)
            if let revision = mutation.revision {
                let all = try writer.fetch(FetchDescriptor<LibrarySchemaV2.TemplateRevisionModel>())
                if let prior = all.first(where: { $0.id == revision.id.rawValue }) {
                    guard try decode(prior) == revision else { throw LibraryRepositoryError.duplicateID }
                } else { writer.insert(try LibrarySchemaV2.TemplateRevisionModel(revision)) }
            }
            if result == existing { return result }
            if identity == nil { writer.insert(LibrarySchemaV1.IdentityModel(ownerID: ownerID)) }
            if let model {
                model.currentRevisionID = result.currentRevision.id.rawValue
                model.isArchived = result.isArchived
            } else { writer.insert(LibrarySchemaV2.TemplateModel(result)) }
            try save(writer)
            let reader = ModelContext(container)
            guard let durable = try reader.fetch(FetchDescriptor<LibrarySchemaV2.TemplateModel>()).first(where: { $0.id == result.id.rawValue }),
                  try template(durable, in: reader) == result else { throw LibraryRepositoryError.verificationFailed }
            return result
        } catch { writer.rollback(); throw error }
    }
    private func template(_ model: LibrarySchemaV2.TemplateModel, in context: ModelContext) throws -> LibraryExerciseTemplate {
        let revisions = try history(model, in: context)
        guard let current = revisions.last,
              let identity = try context.fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).first(where: { $0.key == "local-owner" }),
              model.ownerID == identity.ownerID else { throw LibraryRepositoryError.corruptStore }
        return LibraryExerciseTemplate(id: LibraryTemplateID(rawValue: model.id), ownerID: LibraryOwnerID(rawValue: model.ownerID),
                                       currentRevision: current, isArchived: model.isArchived)
    }
    private func history(_ model: LibrarySchemaV2.TemplateModel, in context: ModelContext) throws -> [LibraryExerciseTemplateRevision] {
        let revisions = try context.fetch(FetchDescriptor<LibrarySchemaV2.TemplateRevisionModel>()).filter { $0.templateID == model.id }.map(decode)
        var ordered: [LibraryExerciseTemplateRevision] = []
        var current: LibraryTemplateRevisionID? = LibraryTemplateRevisionID(rawValue: model.currentRevisionID)
        var visited: Set<LibraryTemplateRevisionID> = []
        while let id = current {
            guard visited.insert(id).inserted, let revision = revisions.first(where: { $0.id == id }) else { throw LibraryRepositoryError.corruptStore }
            ordered.append(revision)
            current = revision.parentRevisionID
        }
        guard !ordered.isEmpty, ordered.count == revisions.count else { throw LibraryRepositoryError.corruptStore }
        return ordered.reversed()
    }
    private func decode(_ model: LibrarySchemaV2.TemplateRevisionModel) throws -> LibraryExerciseTemplateRevision {
        guard let value = try? JSONDecoder().decode(LibraryExerciseTemplateRevision.self, from: model.payload),
              value.id.rawValue == model.id, value.templateID.rawValue == model.templateID,
              value.content.validationIssues.isEmpty, value.createdAt.timeIntervalSince1970.isFinite else {
            throw LibraryRepositoryError.corruptStore
        }
        return value
    }
}
