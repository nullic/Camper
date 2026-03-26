import Foundation

public extension Optional where Wrapped: CaseIterable {
    static var allCases: [Wrapped?] {
        var result: [Wrapped?] = [nil]
        for item in Wrapped.allCases {
            result.append(item)
        }
        return result
    }
}
