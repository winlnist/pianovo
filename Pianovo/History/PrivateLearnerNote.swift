import Foundation

nonisolated enum LearnerNoteAudience: String, Codable { case privateLearner }
nonisolated enum LearnerNoteContext: Equatable, Codable {
    case session(PracticeSessionRecord, String)
    case originalDay(ProgrammeDefinitionReference, ProgrammeWeekID, PracticeDayID, String)
    case learnerDay(LearnerPlanID, LearnerPlanRevisionID, UUID, UUID?, String)
    var title: String {
        switch self { case .session(_, let title), .originalDay(_, _, _, let title), .learnerDay(_, _, _, _, let title): title }
    }
    static func day(plan: LearnerPlan, revision: LearnerPlanRevision, dayID: UUID, assignmentID: UUID? = nil) -> Self? {
        for (w, week) in revision.content.weeks.enumerated() {
            if let d = week.days.firstIndex(where: { $0.id == dayID }) {
                return .learnerDay(plan.id, revision.id, dayID, assignmentID, "\(revision.content.name) · Week \(w + 1), Day \(d + 1)")
            }
        }
        return nil
    }
}
nonisolated struct PrivateLearnerNote: Identifiable, Equatable, Codable {
    let id: UUID
    let context: LearnerNoteContext
    let text: String
    let createdAt: PracticeTimestamp
    let audience: LearnerNoteAudience
    func validate() throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !context.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              createdAt.instant.timeIntervalSince1970.isFinite else { throw PrivateLearnerNoteError.invalid }
    }
}
nonisolated enum PrivateLearnerNoteError: Error, Equatable { case invalid, conflict, corruptStore, verificationFailed }
@MainActor
protocol PrivateLearnerNoteRepository {
    func notes() async throws -> [PrivateLearnerNote]
    func save(_ note: PrivateLearnerNote) async throws -> PrivateLearnerNote
}
@MainActor
final class InMemoryPrivateLearnerNoteRepository: PrivateLearnerNoteRepository {
    private var values: [UUID: PrivateLearnerNote] = [:]
    func notes() async throws -> [PrivateLearnerNote] { values.values.sorted { $0.id.uuidString < $1.id.uuidString } }
    func save(_ note: PrivateLearnerNote) async throws -> PrivateLearnerNote {
        try note.validate()
        if let existing = values[note.id], existing != note { throw PrivateLearnerNoteError.conflict }
        values[note.id] = note; return note
    }
}
