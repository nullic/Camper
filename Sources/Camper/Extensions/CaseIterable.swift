import Foundation

public extension CaseIterable {
    static func random() -> Self.AllCases.Element { allCases.randomElement()! }
}
