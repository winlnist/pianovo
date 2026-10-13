import Foundation

/// Application-facing asynchronous boundary; SwiftData access remains on MainActor.
@MainActor
protocol LibraryExerciseRepository {
    func exercises() async throws -> [LibraryExercise]
    func revisionHistory(for id: LibraryExerciseID) async throws -> [LibraryExerciseRevision]
    func apply(_ mutation: LibraryMutation) async throws -> LibraryExercise
}

@MainActor
final class InMemoryLibraryExerciseRepository: LibraryExerciseRepository {
    private let ownerID: LibraryOwnerID
    private var values: [LibraryExerciseID: LibraryExercise] = [:]
    private var revisions: [LibraryExerciseID: [LibraryExerciseRevision]] = [:]

    init(ownerID: LibraryOwnerID = LibraryOwnerID(rawValue: UUID())) { self.ownerID = ownerID }

    func exercises() async throws -> [LibraryExercise] { Array(values.values) }
    func revisionHistory(for id: LibraryExerciseID) async throws -> [LibraryExerciseRevision] {
        guard let history = revisions[id] else { throw LibraryRepositoryError.notFound }
        return history
    }

    func apply(_ mutation: LibraryMutation) async throws -> LibraryExercise {
        if let revision = mutation.revision,
           revisions.values.flatMap({ $0 }).contains(where: { $0.id == revision.id && $0.exerciseID != revision.exerciseID }) {
            throw LibraryRepositoryError.duplicateID
        }
        let result = try mutation.applying(to: values[mutation.exerciseID], history: revisions[mutation.exerciseID] ?? [], ownerID: ownerID)
        if let revision = mutation.revision, !(revisions[mutation.exerciseID] ?? []).contains(revision) {
            revisions[mutation.exerciseID, default: []].append(revision)
        }
        values[result.id] = result
        return result
    }
}
