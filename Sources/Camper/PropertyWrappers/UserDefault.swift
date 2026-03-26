import Combine
import Foundation

private protocol AnyOptional {
    var isNil: Bool { get }
}

extension Optional: AnyOptional {
    public var isNil: Bool { self == nil }
}

@propertyWrapper
public final class UserDefault<Value>: @unchecked Sendable {
    private let key: String
    private let container: UserDefaults
    private let defaultValue: () -> Value
    private let transformer: ValueTransformer?
    private var publisher: CurrentValueSubject<Value, Never>!

    public init(key: String, container: UserDefaults = .standard, transformer: ValueTransformer? = nil, defaultValue: @escaping @autoclosure () -> Value) {
        self.key = key
        self.container = container
        self.transformer = transformer
        self.defaultValue = defaultValue
        self.publisher = CurrentValueSubject<Value, Never>(wrappedValue)
    }

    public var wrappedValue: Value {
        get {
            if let transformer {
                if let data = container.data(forKey: key) {
                    return transformer.reverseTransformedValue(data) as? Value ?? defaultValue()
                } else {
                    return defaultValue()
                }
            } else {
                return container.object(forKey: key) as? Value ?? defaultValue()
            }
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                container.removeObject(forKey: key)
            } else {
                if let transformer {
                    if let data = transformer.transformedValue(newValue) {
                        container.set(data, forKey: key)
                    }
                } else {
                    container.set(newValue, forKey: key)
                }
            }
            container.synchronize()
            publisher.send(newValue)
        }
    }

    public var projectedValue: AnyPublisher<Value, Never> { publisher.eraseToAnyPublisher() }
}

@propertyWrapper
public final class CodableUserDefault<Value>: @unchecked Sendable where Value: Codable {
    private let key: String
    private let container: UserDefaults
    private let defaultValue: () -> Value
    private var publisher: CurrentValueSubject<Value, Never>!

    public init(key: String, container: UserDefaults = .standard, defaultValue: @escaping @autoclosure () -> Value) {
        self.key = key
        self.container = container
        self.defaultValue = defaultValue
        self.publisher = CurrentValueSubject<Value, Never>(wrappedValue)
    }

    public var wrappedValue: Value {
        get {
            guard let data = container.object(forKey: key) as? Data else { return defaultValue() }
            do {
                return try JSONDecoder.base.decode(Value.self, from: data)
            } catch {
                return defaultValue()
            }
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                container.removeObject(forKey: key)
            } else {
                do {
                    let data = try JSONEncoder.base.encode(newValue)
                    container.set(data, forKey: key)
                } catch {
                    container.removeObject(forKey: key)
                }
            }
            container.synchronize()
            publisher.send(newValue)
        }
    }

    public var projectedValue: AnyPublisher<Value, Never> { publisher.eraseToAnyPublisher() }
}
