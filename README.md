# Camper

A Swift macro library providing dependency injection infrastructure, code generation utilities, and common patterns for iOS/macOS apps.

**Requirements:** Swift 6.2+, iOS 17+ / macOS 14+

## Installation

```swift
.package(url: "https://github.com/nullic/Camper.git", from: "1.0.0")
```

```swift
.target(name: "YourTarget", dependencies: ["Camper"])
```

---

## Dependency Injection

The DI system is built around two macros: `@Injector` (the root container) and `@Injection` (scoped dependency protocols for individual features).

### `@Injector`

Attaches to a class and generates all the DI infrastructure: `DefaultInjector` typealias, `Dependencies`/`Outputs` nested protocols, initializers, and `getValue()` accessors.

```swift
@Injector(mock: true, dependenciesMock: true)
class AppInjector {
    @Dependency var api: APIService
    @Dependency var analytics: AnalyticsService
    @Dependency(.explicit) var settings: AppSettings   // passed via init, not Dependencies
    @Output var router: Router
}
```

**Generated output includes:**
- `protocol Dependencies` with all `@Dependency` properties
- `protocol Outputs` with all `@Output` properties
- `init(dependencies:)` and/or `init()` depending on what's declared
- `typealias DefaultInjector = AppInjector`
- `AppInjectorMock.mock` static property (with `mock: true`)
- `AppInjector.DependenciesMock` class (with `dependenciesMock: true`)

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `mock` | `false` | Generates `AppInjectorMock` enum with a static `mock` property |
| `dependenciesMock` | `false` | Generates `AppInjector.DependenciesMock: AppInjector.Dependencies` |

### `@Dependency`

Marks a property in an `@Injector` class as a dependency. Generates a `get` accessor reading from `dependencies.<name>`.

```swift
@Dependency var api: APIService
// Generates: var api: APIService { get { dependencies.api } }
```

**Explicit mode** — the property is passed as an `init` parameter and stored in a private `_ExplicitDependencies` struct, not exposed via the `Dependencies` protocol:

```swift
@Dependency(.explicit) var settings: AppSettings
// Stored in _ExplicitDependencies; init gains a `settings: AppSettings` parameter
```

**Subscript mode** — generates a `@dynamicMemberLookup` subscript for the dependency type on the enclosing class (requires `@dynamicMemberLookup` attribute on the class):

```swift
@Dependency(.subscript) var analytics: AnalyticsService
```

### `@Output`

Marks a property to be part of the injector's `Outputs` protocol.

```swift
@Output var router: Router
@Output(.internal) var cache: Cache   // internal visibility only
```

### `@Injection`

Generates `<Name>Impl` and optionally `<Name>Mock` classes for a DI protocol. The protocol name must end with `Injection`.

```swift
@Injection
protocol HomeInjection {
    var analytics: AnalyticsService { get }
    var api: APIService { get }
}
```

**Generated:**

```swift
// HomeInjectionImpl — resolves from DefaultInjector
final class HomeInjectionImpl: HomeInjection, PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable {
    private let injector: DefaultInjector
    var analytics: AnalyticsService { injector.analytics }
    var api: APIService { injector.api }
    // + getPassedObject / setPassedObject
}

// HomeInjectionMock — for tests
final class HomeInjectionMock: HomeInjection, @unchecked Sendable {
    var _analytics: AnalyticsService!
    var analytics: AnalyticsService { _analytics }
    // ...
}
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `mock` | `true` | Generate `<Name>Mock` class |
| `build` | `false` | Generate `func build(injector:) -> <Name>` factory |
| `injectorType` | `DefaultInjector` | Custom injector type |

**Inheritance** — child injection inherits from parent's `Impl`/`Mock`:

```swift
@Injection(mock: false)
protocol DetailInjection: HomeInjection {
    var detail: DetailService { get }
}
// Generates: class DetailInjectionImpl: HomeInjectionImpl, DetailInjection
```

**Nested injections** — if a property type ends with `Injection`, it's automatically constructed:

```swift
@Injection
protocol HomeInjection {
    var settings: SettingsInjection { get }
}
// Generates: var settings: SettingsInjection { SettingsInjectionImpl(injector: injector, parent: self) }
```

### `@Origin`

Overrides the injector key path for a property in an `@Injection` protocol. Use dot-separated paths:

```swift
@Injection(mock: false)
protocol HomeInjection {
    @Origin("analytics.tracker") var tracker: Tracker { get }
    // Generates: var tracker: Tracker { injector.analytics.tracker }
}
```

### `@Passed`

Marks an optional property for passing objects through the injection chain. The property is stored as a weak reference and can be retrieved by child injections via `PassedObjectsInjection.getPassedObject()`.

```swift
@Injection
protocol HomeInjection {
    @Passed var coordinator: Coordinator? { get set }
}
```

---

## Testing

### `@AutoMockable`

Generates a full spy/mock class for a protocol with call tracking, argument capture, and configurable return values.

```swift
@AutoMockable
protocol AuthRepository {
    func login(email: String, password: String) async throws
    var isLoggedIn: Bool { get }
}
```

**Generated `AuthRepositoryMock` includes:**

```swift
// For each method:
var loginEmailStringPasswordStringCallsCount = 0
var loginEmailStringPasswordStringCalled: Bool { loginEmailStringPasswordStringCallsCount > 0 }
var loginEmailStringPasswordStringReceivedArguments: (email: String, password: String)?
var loginEmailStringPasswordStringReceivedInvocations: [(email: String, password: String)] = []
var loginEmailStringPasswordStringThrowableError: (any Error)?
var loginEmailStringPasswordStringClosure: ((String, String) async throws -> Void)?

func login(email: String, password: String) async throws {
    loginEmailStringPasswordStringCallsCount += 1
    // captures args, throws error, calls closure if set
}

// For non-optional properties:
var underlyingIsLoggedIn: Bool!
var isLoggedIn: Bool {
    get { underlyingIsLoggedIn }
    set { underlyingIsLoggedIn = newValue }
}
```

If the protocol is `public`, the mock and all members are also `public`.

---

## SwiftData

### `@IOModel`

Generates a full input/output layer for a SwiftData `@Model` class: `InputModel` protocol, `Snapshot` struct (Codable, Sendable), and init/update methods.

```swift
@IOModel
@Model
final class Article {
    var title: String
    var body: String
    var publishedAt: Date?

    @Relationship(deleteRule: .cascade)
    var tags: [Tag]
}
```

**Generated output includes:**
- `Article.Snapshot: Codable, Sendable` — a value-type copy of all stored properties
- `Article.InputModel` protocol — for creating/updating articles
- `init(input:)` and `update(input:)` methods

**Helper macros for `@IOModel`:**

| Macro | Effect |
|-------|--------|
| `@Virtual` | Marks a `@Relationship` as computed — excluded from init/update |
| `@NonLinkable` | Prevents `.link` case in the relationship input enum |
| `@Ignorable` | Makes a non-relationship property optional during input (adds `.ignore` case) |

---

## SwiftUI Helpers

### `#hexColor`, `#hexUIColor`, `#hexNSColor`

Create colors from hex literals at compile time. Supports 3, 4, 6, and 8-digit hex formats with or without `#`/`0x` prefix.

```swift
let color = #hexColor("#FF5733")
let adaptive = #hexUIColor("#FFFFFF", "#1A1A1A")  // light, dark
```

### `#localized`

Creates a `LocalizedStringResource` from a string literal:

```swift
let title = #localized("welcome.title")
// Equivalent to: LocalizedStringResource("welcome.title", bundle: .main)
```

---

## Code Generation

### `@MemberwiseInit`

Generates a memberwise `init` for structs. Optional properties automatically get `= nil` default values.

```swift
@MemberwiseInit
struct UserProfile {
    let name: String
    let bio: String?
    let avatarURL: URL?
}
// Generates: init(name: String, bio: String? = nil, avatarURL: URL? = nil)
```

### `@StringRepresentable`

Generates `RawRepresentable` conformance with dot-separated string encoding for enums.

```swift
@StringRepresentable
enum Status {
    case active
    case suspended(reason: String)
}
// active -> "active"
// suspended(reason: "spam") -> "suspended.spam"
```

### `@LoggersCollection`

Generates static `Logger` properties from a nested `Categories` enum.

```swift
@LoggersCollection(subsystem: "com.example.app")
enum AppLoggers {
    enum Categories {
        case network
        case storage
        case ui
    }
}
// Generates: static let network = Logger(subsystem: "com.example.app", category: "network")
// etc.
```

---

## Property Wrappers

### `@Clamped`

Clamps a value to a closed range on every assignment.

```swift
@Clamped(0...100) var volume: Int = 50
volume = 150  // volume == 100
```

`@ClampedNil` is the optional variant that allows `nil`.

### `@LazyAtomic`

Thread-safe lazy initialization using `NSLock`. The value is computed once on first access.

```swift
@LazyAtomic var heavyObject = { HeavyObject() }
```

### `@UserDefault`

Syncs a value with `UserDefaults`. Supports custom `ValueTransformer` and publishes changes via `CurrentValueSubject`.

```swift
@UserDefault("user.onboarded", store: .standard) var hasOnboarded: Bool = false
```

`@CodableUserDefault` stores `Codable` types as JSON.

```swift
@CodableUserDefault("user.preferences") var preferences: UserPreferences?
```

---

## Logging

`CamperLogger` wraps both SwiftyBeaver and OSLog. Configure once at app startup:

```swift
Logger.configure { config in
    config.minimumLevel = .debug
    config.fileLoggingEnabled = true
}
```

---

## License

MIT
