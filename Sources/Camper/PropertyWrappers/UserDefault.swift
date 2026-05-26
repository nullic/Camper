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

    public convenience init(wrappedValue: @autoclosure @escaping () -> Value, _ key: String, store: UserDefaults = .standard, transformer: ValueTransformer? = nil) {
        self.init(key: key, container: store, transformer: transformer, defaultValue: wrappedValue())
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

    /// SwiftUI `ObservableObject` integration via the private
    /// `_enclosingInstance` static-subscript pattern (the same
    /// mechanism `@Published` uses). When the host class conforms
    /// to `ObservableObject`, Swift resolves every read/write
    /// through this subscript instead of `wrappedValue`, so every
    /// setter automatically fires `objectWillChange.send()` and
    /// the host's `@ObservedObject` / `@StateObject` listeners
    /// re-render.
    ///
    /// Non-`ObservableObject` hosts (structs, plain classes)
    /// fall back to the regular `wrappedValue` accessors —
    /// no behavioural change for legacy call sites.
    public static subscript<EnclosingSelf: ObservableObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped _: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, UserDefault>
    ) -> Value where EnclosingSelf.ObjectWillChangePublisher == ObservableObjectPublisher {
        get {
            object[keyPath: storageKeyPath].wrappedValue
        }
        set {
            object.objectWillChange.send()
            object[keyPath: storageKeyPath].wrappedValue = newValue
        }
    }
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

    public convenience init(wrappedValue: @autoclosure @escaping () -> Value, _ key: String, store: UserDefaults = .standard) {
        self.init(key: key, container: store, defaultValue: wrappedValue())
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

    /// SwiftUI `ObservableObject` integration — see the matching
    /// subscript on `UserDefault` for the rationale. When the
    /// host class conforms to `ObservableObject`, every setter
    /// automatically fires `objectWillChange.send()`. Legacy
    /// non-`ObservableObject` call sites continue to use
    /// `wrappedValue` directly.
    public static subscript<EnclosingSelf: ObservableObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped _: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, CodableUserDefault>
    ) -> Value where EnclosingSelf.ObjectWillChangePublisher == ObservableObjectPublisher {
        get {
            object[keyPath: storageKeyPath].wrappedValue
        }
        set {
            object.objectWillChange.send()
            object[keyPath: storageKeyPath].wrappedValue = newValue
        }
    }
}
