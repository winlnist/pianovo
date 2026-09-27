import CoreGraphics
import Testing
@testable import Pianovo

struct SightReadingLayoutTests {
    @Test func portraitAndLandscapeCanGroupSameExerciseDifferently() throws {
        let exercise = try makeExercise(measureCount: 16)
        let policy = SightReadingLayoutPolicy()

        let portraitSystems = policy.systems(for: exercise, availableWidth: 650)
        let landscapeSystems = policy.systems(for: exercise, availableWidth: 920)

        #expect(portraitSystems.map { $0.measures.map(\.id) } != landscapeSystems.map { $0.measures.map(\.id) })
        #expect(portraitSystems.flatMap(\.measures).flatMap(\.events) == exercise.events)
        #expect(landscapeSystems.flatMap(\.measures).flatMap(\.events) == exercise.events)
    }

    @Test func sixteenMeasuresWithSafeMaximumFiveBalancesInsteadOfLeavingOneMeasureFinalSystem() throws {
        let exercise = try makeExercise(measureCount: 16)
        let policy = SightReadingLayoutPolicy(targetPortraitMeasureWidth: 100, maximumMeasuresPerSystem: 5)

        let systems = policy.systems(for: exercise, availableWidth: 500)

        #expect(systems.map { $0.measures.count } == [4, 4, 4, 4])
        #expect(systems.map { $0.measures.count } != [5, 5, 5, 1])
        #expect(systems.allSatisfy { $0.measures.count <= 5 })
        #expect(systems.flatMap(\.measures).map(\.id) == exercise.measures.map(\.id))
    }

    @Test func representativeMeasureTotalsAreBalancedWithinSafeMaximum() throws {
        let policy = SightReadingLayoutPolicy()

        #expect(policy.balancedMeasureCounts(totalMeasures: 8, safeMaximumMeasuresPerSystem: 5) == [4, 4])
        #expect(policy.balancedMeasureCounts(totalMeasures: 10, safeMaximumMeasuresPerSystem: 4) == [4, 3, 3])
        #expect(policy.balancedMeasureCounts(totalMeasures: 12, safeMaximumMeasuresPerSystem: 5) == [4, 4, 4])
        #expect(policy.balancedMeasureCounts(totalMeasures: 14, safeMaximumMeasuresPerSystem: 4) == [4, 4, 3, 3])
        #expect(policy.balancedMeasureCounts(totalMeasures: 16, safeMaximumMeasuresPerSystem: 5) == [4, 4, 4, 4])
    }

    @Test func balancedSystemsPreserveMeasureOrderAndUseEachMeasureOnce() throws {
        let exercise = try makeExercise(measureCount: 14)
        let policy = SightReadingLayoutPolicy(targetPortraitMeasureWidth: 100, maximumMeasuresPerSystem: 4)

        let systems = policy.systems(for: exercise, availableWidth: 400)
        let laidOutMeasures = systems.flatMap(\.measures)

        #expect(systems.map { $0.measures.count } == [4, 4, 3, 3])
        #expect(laidOutMeasures.map(\.id) == exercise.measures.map(\.id))
        #expect(Set(laidOutMeasures.map(\.id)).count == exercise.measures.count)
        #expect(systems.allSatisfy { $0.measures.count <= 4 })
    }

    @Test func balancedGroupSizesDifferByAtMostOneWherePractical() {
        let policy = SightReadingLayoutPolicy()

        for totalMeasures in [8, 10, 12, 14, 16] {
            let counts = policy.balancedMeasureCounts(totalMeasures: totalMeasures, safeMaximumMeasuresPerSystem: 5)

            #expect((counts.max() ?? 0) - (counts.min() ?? 0) <= 1)
            #expect(counts.allSatisfy { $0 <= 5 })
            #expect(counts.reduce(0, +) == totalMeasures)
        }
    }

    @Test func layoutPolicyUsesWidthWithoutChangingEventIdentity() throws {
        let exercise = try makeExercise(measureCount: 8)
        let policy = SightReadingLayoutPolicy()
        let currentEventIndex = 17
        let currentEventID = exercise.events[currentEventIndex].id

        let compactSystems = policy.systems(for: exercise, availableWidth: 360)
        let wideSystems = policy.systems(for: exercise, availableWidth: 900)

        #expect(compactSystems.flatMap(\.measures).flatMap(\.events)[currentEventIndex].id == currentEventID)
        #expect(wideSystems.flatMap(\.measures).flatMap(\.events)[currentEventIndex].id == currentEventID)
        #expect(compactSystems.flatMap(\.measures).flatMap(\.events) == exercise.events)
        #expect(wideSystems.flatMap(\.measures).flatMap(\.events) == exercise.events)
    }

    @Test func deterministicMeasuresPerSystemBehavior() {
        let policy = SightReadingLayoutPolicy()

        #expect(policy.measuresPerSystem(for: 360) == 2)
        #expect(policy.measuresPerSystem(for: 650) == 4)
        #expect(policy.measuresPerSystem(for: 920) == 6)
    }

    private func makeExercise(measureCount: Int) throws -> ReadingExercise {
        let range = try #require(PitchRange(lowerBound: Pitch(.c, octave: 4), upperBound: Pitch(.g, octave: 4)))
        let configuration = PracticeConfiguration(
            pitchRange: range,
            mode: .trebleReading,
            measureCount: measureCount,
            eventsPerMeasure: 4
        )
        var index = 0
        var generator = ReadingExerciseGenerator(configuration: configuration) { upperBound in
            defer { index += 1 }
            return index % upperBound
        }

        return generator.nextExercise()
    }
}
