import Foundation

protocol PracticeClock {
    nonisolated
    var now: Date { get }
}

nonisolated struct SystemPracticeClock: PracticeClock {
    var now: Date {
        Date()
    }
}

nonisolated struct FixedPracticeClock: PracticeClock {
    let now: Date
}

protocol PracticeLocalContextProviding {
    nonisolated
    var timeZone: TimeZone { get }
    nonisolated
    var calendarIdentifier: PracticeCalendarIdentifier { get }
}

nonisolated struct SystemPracticeLocalContextProvider: PracticeLocalContextProviding {
    let timeZone: TimeZone
    let calendarIdentifier: PracticeCalendarIdentifier

    init(
        timeZone: TimeZone = .autoupdatingCurrent,
        calendarIdentifier: PracticeCalendarIdentifier = .gregorian
    ) {
        self.timeZone = timeZone
        self.calendarIdentifier = calendarIdentifier
    }
}

nonisolated struct FixedPracticeLocalContextProvider: PracticeLocalContextProviding {
    let timeZone: TimeZone
    let calendarIdentifier: PracticeCalendarIdentifier
}

nonisolated struct PracticeTemporalContext {
    let now: Date
    let localDay: LocalDayContext
    let suggestedSessionSlot: PracticeSessionSlot?

    init(
        clock: any PracticeClock,
        localContextProvider: any PracticeLocalContextProviding
    ) {
        let now = clock.now
        self.now = now
        self.localDay = LocalDayContext(
            timestamp: now,
            timeZone: localContextProvider.timeZone,
            calendarIdentifier: localContextProvider.calendarIdentifier
        )
        self.suggestedSessionSlot = Self.suggestedSessionSlot(
            for: now,
            timeZone: localContextProvider.timeZone,
            calendarIdentifier: localContextProvider.calendarIdentifier
        )
    }

    private static func suggestedSessionSlot(
        for date: Date,
        timeZone: TimeZone,
        calendarIdentifier: PracticeCalendarIdentifier
    ) -> PracticeSessionSlot {
        var calendar = Calendar(identifier: calendarIdentifier.foundationIdentifier)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        return hour < 12 ? .morning : .evening
    }
}
