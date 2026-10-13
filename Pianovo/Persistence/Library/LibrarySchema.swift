import Foundation
import SwiftData

enum LibrarySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [ExerciseModel.self, RevisionModel.self, IdentityModel.self] }

    @Model final class ExerciseModel {
        @Attribute(.unique) var id: UUID
        var ownerID: UUID
        var currentRevisionID: UUID
        var isArchived: Bool
        init(_ exercise: LibraryExercise) {
            id = exercise.id.rawValue
            ownerID = exercise.ownerID.rawValue
            currentRevisionID = exercise.currentRevision.id.rawValue
            isArchived = exercise.isArchived
        }
    }

    @Model final class RevisionModel {
        @Attribute(.unique) var id: UUID
        var exerciseID: UUID
        var payload: Data
        init(_ revision: LibraryExerciseRevision) throws {
            id = revision.id.rawValue
            exerciseID = revision.exerciseID.rawValue
            payload = try JSONEncoder().encode(revision)
        }
    }

    @Model final class IdentityModel {
        @Attribute(.unique) var key: String
        var ownerID: UUID
        init(ownerID: LibraryOwnerID) { key = "local-owner"; self.ownerID = ownerID.rawValue }
    }
}

enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self, LibrarySchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: LibrarySchemaV1.self, toVersion: LibrarySchemaV2.self)] }
}

@MainActor
enum LibraryModelContainerFactory {
    static func configuration(inMemory: Bool = false, storeURL: URL? = nil) -> ModelConfiguration {
        let schema = Schema(versionedSchema: LibrarySchemaV2.self)
        if inMemory && storeURL == nil {
            return ModelConfiguration("PianovoLibrary", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        let url = storeURL ?? URL.applicationSupportDirectory.appendingPathComponent("PianovoLibrary.store")
        return ModelConfiguration("PianovoLibrary", schema: schema, url: url, cloudKitDatabase: .none)
    }

    static func makeContainer(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LibrarySchemaV2.self)
        let configuration = configuration(inMemory: inMemory, storeURL: storeURL)
        if !configuration.isStoredInMemoryOnly {
            try FileManager.default.createDirectory(at: configuration.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        return try ModelContainer(for: schema, migrationPlan: LibraryMigrationPlan.self, configurations: [configuration])
    }
}
