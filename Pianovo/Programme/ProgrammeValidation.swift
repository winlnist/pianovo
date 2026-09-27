import Foundation

nonisolated struct ProgrammeValidationIssue: Hashable {
    let code: ProgrammeValidationCode
    let path: String
    let message: String
}

nonisolated enum ProgrammeValidationCode: String, Hashable {
    case duplicateID
    case invalidOrdering
    case invalidDuration
    case unresolvedSourceReference
    case unresolvedMasteryRuleReference
    case missingRequiredField
    case invalidMasteryRule
    case invalidProgrammeLength
    case invalidWeekShape
    case invalidPracticeDayShape
    case invalidBeyerProgression
}

nonisolated struct ProgrammeValidator {
    func validate(
        _ programme: PracticeProgramme,
        sourceCatalogue: ExerciseSourceCatalogue
    ) -> [ProgrammeValidationIssue] {
        var issues: [ProgrammeValidationIssue] = []

        issues += duplicateIssues(programme)
        issues += duplicateSourceIssues(sourceCatalogue)
        issues += orderingIssues(programme)
        issues += requiredFieldIssues(programme, sourceCatalogue: sourceCatalogue)
        issues += referenceIssues(programme, sourceCatalogue: sourceCatalogue)
        issues += masteryRuleIssues(programme)

        return issues
    }

    private func duplicateIssues(_ programme: PracticeProgramme) -> [ProgrammeValidationIssue] {
        var issues: [ProgrammeValidationIssue] = []

        issues += duplicateIssues(programme.weeks.map { $0.id.rawValue }, path: "programme.weeks")

        for week in programme.weeks {
            issues += duplicateIssues(week.days.map { $0.id.rawValue }, path: "programme.weeks[\(week.number)].days")

            for day in week.days {
                issues += duplicateIssues(day.blocks.map { $0.id.rawValue }, path: "week-\(week.number).day-\(day.dayNumber).blocks")
                let assignmentIDs = day.blocks.flatMap { $0.assignments.map(\.id.rawValue) }
                issues += duplicateIssues(assignmentIDs, path: "week-\(week.number).day-\(day.dayNumber).assignments")
            }
        }

        issues += duplicateIssues(programme.masteryRules.map { $0.id.rawValue }, path: "programme.masteryRules")
        return issues
    }

    private func duplicateSourceIssues(_ sourceCatalogue: ExerciseSourceCatalogue) -> [ProgrammeValidationIssue] {
        duplicateIssues(sourceCatalogue.sources.map { $0.id.rawValue }, path: "sourceCatalogue.sources")
    }

    private func duplicateIssues(_ rawValues: [String], path: String) -> [ProgrammeValidationIssue] {
        var seen: Set<String> = []
        var duplicates: Set<String> = []

        for rawValue in rawValues where !seen.insert(rawValue).inserted {
            duplicates.insert(rawValue)
        }

        return duplicates.sorted().map { duplicate in
            ProgrammeValidationIssue(
                code: .duplicateID,
                path: path,
                message: "Duplicate stable ID '\(duplicate)'."
            )
        }
    }

    private func orderingIssues(_ programme: PracticeProgramme) -> [ProgrammeValidationIssue] {
        var issues: [ProgrammeValidationIssue] = []
        issues += orderingIssues(programme.weeks.map(\.number), path: "programme.weeks")

        for week in programme.weeks {
            issues += orderingIssues(week.days.map(\.dayNumber), path: "programme.weeks[\(week.number)].days")

            for day in week.days where day.weekNumber != week.number {
                issues.append(
                    ProgrammeValidationIssue(
                        code: .invalidOrdering,
                        path: "programme.weeks[\(week.number)].days[\(day.dayNumber)].weekNumber",
                        message: "Practice day week number must match its containing week."
                    )
                )
            }
        }

        return issues
    }

    private func orderingIssues(_ numbers: [Int], path: String) -> [ProgrammeValidationIssue] {
        guard !numbers.isEmpty, numbers == Array(1...numbers.count) else {
            return [
                ProgrammeValidationIssue(
                    code: .invalidOrdering,
                    path: path,
                    message: "Items must be numbered contiguously from 1 in display order."
                )
            ]
        }

        return []
    }

    private func requiredFieldIssues(
        _ programme: PracticeProgramme,
        sourceCatalogue: ExerciseSourceCatalogue
    ) -> [ProgrammeValidationIssue] {
        var issues: [ProgrammeValidationIssue] = []

        if programme.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missing(path: "programme.title"))
        }

        if programme.progressionPrinciple.isEmpty {
            issues.append(.missing(path: "programme.progressionPrinciple"))
        }

        if sourceCatalogue.sources.isEmpty {
            issues.append(.missing(path: "sourceCatalogue.sources"))
        }

        for week in programme.weeks {
            if week.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.missing(path: "programme.weeks[\(week.number)].title"))
            }

            for day in week.days {
                if day.blocks.isEmpty {
                    issues.append(.missing(path: "programme.weeks[\(week.number)].days[\(day.dayNumber)].blocks"))
                }

                for block in day.blocks {
                    if block.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(.missing(path: "block.\(block.id.rawValue).title"))
                    }

                    if block.targetDurationMinutes <= 0 {
                        issues.append(
                            ProgrammeValidationIssue(
                                code: .invalidDuration,
                                path: "block.\(block.id.rawValue).targetDurationMinutes",
                                message: "Practice block duration must be positive."
                            )
                        )
                    }

                    for assignment in block.assignments {
                        if assignment.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            issues.append(.missing(path: "assignment.\(assignment.id.rawValue).title"))
                        }

                        if assignment.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            issues.append(.missing(path: "assignment.\(assignment.id.rawValue).goal"))
                        }
                    }
                }
            }
        }

        return issues
    }

    private func referenceIssues(
        _ programme: PracticeProgramme,
        sourceCatalogue: ExerciseSourceCatalogue
    ) -> [ProgrammeValidationIssue] {
        let masteryRuleIDs = Set(programme.masteryRules.map(\.id))
        var issues: [ProgrammeValidationIssue] = []

        for week in programme.weeks {
            for day in week.days {
                for block in day.blocks {
                    for assignment in block.assignments {
                        if !sourceCatalogue.contains(assignment.sourceID) {
                            issues.append(
                                ProgrammeValidationIssue(
                                    code: .unresolvedSourceReference,
                                    path: "assignment.\(assignment.id.rawValue).sourceID",
                                    message: "Assignment source reference '\(assignment.sourceID.rawValue)' is not in the supplied source catalogue."
                                )
                            )
                        }

                        if let masteryRuleID = assignment.masteryRuleID, !masteryRuleIDs.contains(masteryRuleID) {
                            issues.append(
                                ProgrammeValidationIssue(
                                    code: .unresolvedMasteryRuleReference,
                                    path: "assignment.\(assignment.id.rawValue).masteryRuleID",
                                    message: "Assignment mastery rule reference '\(masteryRuleID.rawValue)' is not in the programme."
                                )
                            )
                        }
                    }
                }
            }
        }

        return issues
    }

    private func masteryRuleIssues(_ programme: PracticeProgramme) -> [ProgrammeValidationIssue] {
        programme.masteryRules.flatMap { rule in
            var issues: [ProgrammeValidationIssue] = []

            if rule.version <= 0 {
                issues.append(
                    ProgrammeValidationIssue(
                        code: .invalidMasteryRule,
                        path: "masteryRule.\(rule.id.rawValue).version",
                        message: "Mastery rule version must be positive."
                    )
                )
            }

            if rule.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.missing(path: "masteryRule.\(rule.id.rawValue).title"))
            }

            if rule.criteria.isEmpty {
                issues.append(
                    ProgrammeValidationIssue(
                        code: .invalidMasteryRule,
                        path: "masteryRule.\(rule.id.rawValue).criteria",
                        message: "Mastery rule must define at least one explicit criterion."
                    )
                )
            }

            for criterion in rule.criteria {
                if !criterion.isValid {
                    issues.append(
                        ProgrammeValidationIssue(
                            code: .invalidMasteryRule,
                            path: "masteryRule.\(rule.id.rawValue).criteria",
                            message: "Mastery rule criteria must use positive thresholds."
                        )
                    )
                }
            }

            return issues
        }
    }
}

nonisolated struct PianovoProgrammePolicyValidator {
    func validate(_ programme: PracticeProgramme) -> [ProgrammeValidationIssue] {
        var issues: [ProgrammeValidationIssue] = []

        if programme.weeks.count != 12 {
            issues.append(
                ProgrammeValidationIssue(
                    code: .invalidProgrammeLength,
                    path: "programme.weeks",
                    message: "Pianovo programme must contain exactly twelve weeks."
                )
            )
        }

        for week in programme.weeks {
            if week.days.count != 7 {
                issues.append(
                    ProgrammeValidationIssue(
                        code: .invalidWeekShape,
                        path: "programme.weeks[\(week.number)].days",
                        message: "Pianovo weeks must contain seven days."
                    )
                )
            }

            let practiceDayCount = week.days.filter { $0.kind == .practice }.count
            let recoveryDayCount = week.days.filter { $0.kind == .recoveryReflection }.count
            if practiceDayCount != 6 || recoveryDayCount != 1 {
                issues.append(
                    ProgrammeValidationIssue(
                        code: .invalidWeekShape,
                        path: "programme.weeks[\(week.number)].days",
                        message: "Pianovo weeks must contain six practice days and one recovery/reflection day."
                    )
                )
            }

            for day in week.days where day.kind == .practice {
                let slots = Set(day.blocks.map(\.sessionSlot))
                if !slots.contains(.morning) || !slots.contains(.evening) {
                    issues.append(
                        ProgrammeValidationIssue(
                            code: .invalidPracticeDayShape,
                            path: "programme.weeks[\(week.number)].days[\(day.dayNumber)].blocks",
                            message: "Pianovo practice days should include morning and evening practice blocks."
                        )
                    )
                }
            }
        }

        return issues
    }
}

private extension ProgrammeValidationIssue {
    nonisolated static func missing(path: String) -> ProgrammeValidationIssue {
        ProgrammeValidationIssue(
            code: .missingRequiredField,
            path: path,
            message: "Required field is missing."
        )
    }
}

private extension MasteryCriterion {
    nonisolated var isValid: Bool {
        switch self {
        case .qualifyingAttempts(let count, _):
            count > 0
        case .minimumAccuracyPercent(let percent):
            (1...100).contains(percent)
        case .maximumHesitationCount(let count):
            count >= 0
        case .teacherOrUserOverrideAllowed:
            true
        }
    }
}
