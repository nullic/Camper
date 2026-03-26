import Foundation

public struct ValidationError<Model, T>: LocalizedError, @unchecked Sendable {
    public let keyPath: KeyPath<Model, T>
    public let value: T

    public static func invalidValue(for keyPath: KeyPath<Model, T>, value: T) -> Self {
        self.init(keyPath: keyPath, value: value)
    }

    public var errorDescription: String? {
        "Invalid value for \(keyPath): \(value)"
    }
}
