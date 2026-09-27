import SwiftData

enum PracticeHistoryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PracticeHistorySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum PracticeHistoryModelContainerFactory {
    @MainActor
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(PracticeHistorySchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: schema,
            migrationPlan: PracticeHistoryMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
