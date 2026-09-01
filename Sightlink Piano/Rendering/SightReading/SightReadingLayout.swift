import CoreGraphics

nonisolated struct SightReadingLayoutPolicy: Hashable {
    var minimumMeasureWidth: CGFloat = 118
    var targetPortraitMeasureWidth: CGFloat = 150
    var maximumMeasuresPerSystem: Int = 6

    func systems(for exercise: ReadingExercise, availableWidth: CGFloat) -> [SightReadingSystem] {
        let safeMaximum = measuresPerSystem(for: availableWidth)
        let measureCounts = balancedMeasureCounts(totalMeasures: exercise.measures.count, safeMaximumMeasuresPerSystem: safeMaximum)
        var measureStartIndex = 0

        return measureCounts.enumerated().map { index, measureCount in
            defer {
                measureStartIndex += measureCount
            }

            let measures = Array(exercise.measures[measureStartIndex..<(measureStartIndex + measureCount)])
            return SightReadingSystem(index: index, measures: measures)
        }
    }

    func measuresPerSystem(for availableWidth: CGFloat) -> Int {
        let contentWidth = max(minimumMeasureWidth, availableWidth)
        let targetCount = Int((contentWidth / targetPortraitMeasureWidth).rounded(.down))
        return max(1, min(maximumMeasuresPerSystem, targetCount))
    }

    func balancedMeasureCounts(totalMeasures: Int, safeMaximumMeasuresPerSystem: Int) -> [Int] {
        guard totalMeasures > 0 else {
            return []
        }

        let safeMaximum = max(1, safeMaximumMeasuresPerSystem)
        let systemCount = Int(ceil(Double(totalMeasures) / Double(safeMaximum)))
        let baseCount = totalMeasures / systemCount
        let largerSystemCount = totalMeasures % systemCount

        return (0..<systemCount).map { index in
            baseCount + (index < largerSystemCount ? 1 : 0)
        }
    }
}

nonisolated struct SightReadingSystem: Identifiable, Hashable {
    let index: Int
    let measures: [ReadingMeasure]

    var id: Int {
        index
    }
}
