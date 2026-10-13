import Foundation
import SwiftData

@MainActor
final class SwiftDataLibraryExerciseRepository: LibraryExerciseRepository {
    private let container: ModelContainer
    private let save: (ModelContext) throws -> Void
    private let makeOwnerID: () -> LibraryOwnerID

    init(container: ModelContainer, save: @escaping (ModelContext) throws -> Void = { try $0.save() },
         makeOwnerID: @escaping () -> LibraryOwnerID = { LibraryOwnerID(rawValue: UUID()) }) {
        self.container = container
        self.save = save
        self.makeOwnerID = makeOwnerID
    }

    func exercises() async throws -> [LibraryExercise] {
        let reader = ModelContext(container)
        return try reader.fetch(FetchDescriptor<LibrarySchemaV1.ExerciseModel>()).map { try exercise($0, in: reader) }
    }

    func revisionHistory(for id: LibraryExerciseID) async throws -> [LibraryExerciseRevision] {
        let reader = ModelContext(container)
        guard let model = try reader.fetch(FetchDescriptor<LibrarySchemaV1.ExerciseModel>()).first(where: { $0.id == id.rawValue }) else {
            throw LibraryRepositoryError.notFound
        }
        return try history(model, in: reader)
    }

    func apply(_ mutation: LibraryMutation) async throws -> LibraryExercise {
        let writer = ModelContext(container)
        writer.autosaveEnabled = false
        do {
            let model = try writer.fetch(FetchDescriptor<LibrarySchemaV1.ExerciseModel>()).first { $0.id == mutation.exerciseID.rawValue }
            let existing = try model.map { try exercise($0, in: writer) }
            let revisions = try model.map { try history($0, in: writer) } ?? []
            let identity = try writer.fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).first { $0.key == "local-owner" }
            if let model, model.ownerID != identity?.ownerID { throw LibraryRepositoryError.corruptStore }
            let ownerID = identity.map { LibraryOwnerID(rawValue: $0.ownerID) } ?? makeOwnerID()
            let result = try mutation.applying(to: existing, history: revisions, ownerID: ownerID)
            if let revision = mutation.revision {
                let all = try writer.fetch(FetchDescriptor<LibrarySchemaV1.RevisionModel>())
                if let prior = all.first(where: { $0.id == revision.id.rawValue }) {
                    guard try decode(prior) == revision else { throw LibraryRepositoryError.duplicateID }
                } else {
                    writer.insert(try LibrarySchemaV1.RevisionModel(revision))
                }
            }
            if existing == result { return result }
            if identity == nil { writer.insert(LibrarySchemaV1.IdentityModel(ownerID: ownerID)) }
            if let model {
                model.currentRevisionID = result.currentRevision.id.rawValue
                model.isArchived = result.isArchived
            } else { writer.insert(LibrarySchemaV1.ExerciseModel(result)) }
            try save(writer)
            let reader = ModelContext(container)
            guard let durable = try reader.fetch(FetchDescriptor<LibrarySchemaV1.ExerciseModel>()).first(where: { $0.id == result.id.rawValue }),
                  try exercise(durable, in: reader) == result else { throw LibraryRepositoryError.verificationFailed }
            return result
        } catch {
            writer.rollback()
            throw error
        }
    }

    private func exercise(_ model: LibrarySchemaV1.ExerciseModel, in context: ModelContext) throws -> LibraryExercise {
        let revisions = try history(model, in: context)
        guard let current = revisions.last,
              let identity = try context.fetch(FetchDescriptor<LibrarySchemaV1.IdentityModel>()).first(where: { $0.key == "local-owner" }),
              model.ownerID == identity.ownerID else { throw LibraryRepositoryError.corruptStore }
        return LibraryExercise(id: LibraryExerciseID(rawValue: model.id), ownerID: LibraryOwnerID(rawValue: model.ownerID),
                               currentRevision: current, isArchived: model.isArchived)
    }

    private func history(_ model: LibrarySchemaV1.ExerciseModel, in context: ModelContext) throws -> [LibraryExerciseRevision] {
        let revisions = try context.fetch(FetchDescriptor<LibrarySchemaV1.RevisionModel>())
            .filter { $0.exerciseID == model.id }.map(decode)
        var ordered: [LibraryExerciseRevision] = []
        var current: LibraryRevisionID? = LibraryRevisionID(rawValue: model.currentRevisionID)
        var visited: Set<LibraryRevisionID> = []
        while let id = current {
            guard visited.insert(id).inserted, let revision = revisions.first(where: { $0.id == id }) else {
                throw LibraryRepositoryError.corruptStore
            }
            ordered.append(revision)
            current = revision.parentRevisionID
        }
        guard !ordered.isEmpty, ordered.count == revisions.count else { throw LibraryRepositoryError.corruptStore }
        return ordered.reversed()
    }

    private func decode(_ model: LibrarySchemaV1.RevisionModel) throws -> LibraryExerciseRevision {
        guard let value = try? JSONDecoder().decode(LibraryExerciseRevision.self, from: model.payload),
              value.id.rawValue == model.id, value.exerciseID.rawValue == model.exerciseID,
              value.content.validationIssues.isEmpty, value.createdAt.timeIntervalSince1970.isFinite else {
            throw LibraryRepositoryError.corruptStore
        }
        return value
    }
}
