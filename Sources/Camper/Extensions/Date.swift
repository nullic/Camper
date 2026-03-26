import Foundation

public extension Date {
    static func randomFromNow(to date: Date) -> Date {
        randomBetween(start: date, end: Date())
    }

    static func randomBetween(start: Date, end: Date) -> Date {
        var date1 = start
        var date2 = end
        if date2 < date1 {
            let temp = date1
            date1 = date2
            date2 = temp
        }
        let span = TimeInterval.random(in: date1.timeIntervalSinceNow ... date2.timeIntervalSinceNow)
        return Date(timeIntervalSinceNow: span)
    }
}
