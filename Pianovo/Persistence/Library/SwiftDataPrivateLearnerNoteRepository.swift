import Foundation
import SwiftData

@MainActor
final class SwiftDataPrivateLearnerNoteRepository: PrivateLearnerNoteRepository {
    private let container: ModelContainer
    private let saveContext: (ModelContext) throws -> Void
    init(container: ModelContainer, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.container = container; saveContext = save
    }
    func notes() async throws -> [PrivateLearnerNote] { try read(ModelContext(container)) }
    func save(_ note: PrivateLearnerNote) async throws -> PrivateLearnerNote {
        try note.validate()
        let writer = ModelContext(container); writer.autosaveEnabled = false
        do {
            if let existing = try read(writer).first(where: { $0.id == note.id }) {
                guard existing == note else { throw PrivateLearnerNoteError.conflict }; return existing
            }
            writer.insert(try LibrarySchemaV5.PrivateNoteModel(note))
            try saveContext(writer)
            guard try read(ModelContext(container)).contains(note) else { throw PrivateLearnerNoteError.verificationFailed }
            return note
        } catch { writer.rollback(); throw error }
    }
    private func read(_ context: ModelContext) throws -> [PrivateLearnerNote] {
        try context.fetch(FetchDescriptor<LibrarySchemaV5.PrivateNoteModel>()).map { row in
            let note = try JSONDecoder().decode(PrivateLearnerNote.self, from: row.payload)
            try note.validate()
            guard row.id == note.id else { throw PrivateLearnerNoteError.corruptStore }
            return note
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
