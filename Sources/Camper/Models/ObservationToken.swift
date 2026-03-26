import Combine
import Foundation

public final class ObservationToken<Value>: Sendable, CustomStringConvertible, Hashable, Equatable {
    public typealias OnChange = @Sendable (Value) -> Void
    public typealias OnCancel = @Sendable (UUID) -> Void

    public let uuid = UUID()
    private let onCancel: OnCancel
    private let onChange: OnChange

    public var description: String { "\(type(of: self))<\(uuid)>" }

    public init(onChange: @escaping OnChange, onCancel: @escaping OnCancel) {
        self.onChange = onChange
        self.onCancel = onCancel
    }

    public func notify(value: Value) {
        onChange(value)
    }

    deinit {
        onCancel(uuid)
    }

    public static func == (lhs: ObservationToken, rhs: ObservationToken) -> Bool {
        lhs.uuid == rhs.uuid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}
