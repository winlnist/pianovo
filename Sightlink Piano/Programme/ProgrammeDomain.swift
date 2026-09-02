import Foundation

nonisolated struct PracticeProgrammeID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct ProgrammeWeekID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct PracticeDayID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct PracticeBlockID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct PracticeAssignmentID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct ExerciseSourceID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct MasteryRuleID: Codable, Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }
}

nonisolated struct PracticeProgramme: Codable, Hashable {
    let id: PracticeProgrammeID
    let title: String
    let progressionPrinciple: [PracticeProgressionFocus]
    let weeks: [ProgrammeWeek]
    let masteryRules: [MasteryRule]
}

nonisolated struct ProgrammeWeek: Identifiable, Codable, Hashable {
    let id: ProgrammeWeekID
    let number: Int
    let title: String
    let days: [PracticeDay]
}

nonisolated struct PracticeDay: Identifiable, Codable, Hashable {
    let id: PracticeDayID
    let weekNumber: Int
    let dayNumber: Int
    let kind: PracticeDayKind
    let blocks: [PracticeBlock]
}

nonisolated struct PracticeBlock: Identifiable, Codable, Hashable {
    let id: PracticeBlockID
    let title: String
    let category: PracticeCategory
    let sessionSlot: PracticeSessionSlot
    let targetDurationMinutes: Int
    let assignments: [PracticeAssignment]
}

nonisolated struct PracticeAssignment: Identifiable, Codable, Hashable {
    let id: PracticeAssignmentID
    let title: String
    let sourceID: ExerciseSourceID
    let goal: String
    let masteryRuleID: MasteryRuleID?
    let remediationOnly: Bool
}

nonisolated struct ExerciseSourceCatalogue: Codable, Hashable {
    let sources: [ExerciseSource]

    func contains(_ sourceID: ExerciseSourceID) -> Bool {
        sources.contains { $0.id == sourceID }
    }

    func source(withID sourceID: ExerciseSourceID) -> ExerciseSource? {
        sources.first { $0.id == sourceID }
    }
}

nonisolated struct ExerciseSource: Identifiable, Codable, Hashable {
    let id: ExerciseSourceID
    let kind: ExerciseSourceKind
    let collectionTitle: String?
    let exerciseIdentifier: String?
    let displayTitle: String
    let beyerExerciseNumber: Int?
}

nonisolated enum ExerciseSourceKind: String, Codable, Hashable {
    case warmUp
    case technique
    case beyer
    case repertoireHarmony
    case sightReading
    case review
    case reflection
}

nonisolated enum PracticeProgressionFocus: String, Codable, Hashable {
    case quality
    case consistency
    case fluency
    case speed
}

nonisolated enum PracticeDayKind: String, Codable, Hashable {
    case practice
    case recoveryReflection
}

nonisolated enum PracticeCategory: String, Codable, Hashable {
    case warmUp
    case technique
    case beyer
    case repertoireHarmony
    case sightReading
    case review
    case reflection
}

nonisolated enum PracticeSessionSlot: String, Codable, Hashable {
    case morning
    case evening
    case recovery
}

nonisolated enum MasteryState: String, CaseIterable, Codable, Hashable {
    case learning
    case stabilizing
    case nearlyMastered
    case mastered
}

nonisolated struct MasteryRule: Identifiable, Codable, Hashable {
    let id: MasteryRuleID
    let version: Int
    let title: String
    let criteria: [MasteryCriterion]
    let allowsManualOverride: Bool
}

nonisolated enum MasteryCriterion: Codable, Hashable {
    case qualifyingAttempts(count: Int, onSeparatePracticeDays: Bool)
    case minimumAccuracyPercent(Int)
    case maximumHesitationCount(Int)
    case teacherOrUserOverrideAllowed
}
