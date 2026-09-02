<p align="center">
  <img src="assets/icon.svg" width="128" height="128" alt="Camper">
</p>

# Camper

A Swift macro library providing dependency injection infrastructure, code generation utilities, and common patterns for iOS/macOS apps.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnullic%2FCamper%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/nullic/Camper)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnullic%2FCamper%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/nullic/Camper)
[![](https://img.shields.io/github/v/release/nullic/Camper)](https://github.com/nullic/Camper/releases)
[![](https://img.shields.io/github/license/nullic/Camper)](LICENSE)

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

### `@MockName`

Overrides the prefix used for one method's generated members. By default the prefix is built from the method name plus every parameter's label and type, which is long and overload-sensitive:

```swift
@AutoMockable
protocol AuthRepository {
    @MockName("login")
    func login(email: String, password: String) async throws
}
// loginCallsCount, loginReceivedArguments, loginClosure, …
```

The override is applied verbatim — two methods sharing a `@MockName` are a duplicate-symbol error at compile time.

**Known limitations**
- Generated member names embed each parameter's label and type, so they are long and hard to predict; `@MockName` is the escape hatch.
- `@MainActor` and complex `async`/`throws` combinations are not covered by macro-level tests — treat them as unverified until exercised in your own suite.

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

Create colors from hex literals at compile time. Supports 3 (RGB), 4 (RGBA), 6 (RRGGBB), and 8 (RRGGBBAA) digit formats, with or without a `#` / `0x` prefix, in both string- and integer-literal form.

```swift
let color = #hexColor("#FF5733")
let same  = #hexColor(0xFF5733)
```

Passing two literals gives a **light/dark adaptive** color:

```swift
let text = #hexColor("2A2118", "E8E0D2")     // plain SwiftUI Color
let bg   = #hexUIColor("#FFFFFF", "#1A1A1A") // UIKit only
let line = #hexNSColor(0xFFFFFF, 0x000000)   // AppKit only
```

The two-argument `#hexColor` is the cross-platform one: it expands to a `UIColor`-backed adaptive `Color` on UIKit hosts and an `NSColor`-backed one on AppKit hosts, so palette code needs no `#if canImport(UIKit)` of its own. The expansion is a single expression, so it works in a computed-property body.

### `#cssColor`, `#cssUIColor`, `#cssNSColor`

Same three return types, but accepting CSS spellings: hex (`#FFF`, `#FFFF`, `#FFFFFF`, `#FFFFFFFF`), `rgb(r, g, b)` and `rgba(r, g, b, a)` — R/G/B are `0...255`, alpha is `0...1`. The UIKit/AppKit variants also take a light/dark pair.

```swift
let red      = #cssColor("#FF0000")
let green    = #cssColor("rgb(0, 255, 0)")
let semiBlue = #cssColor("rgba(0, 0, 255, 0.5)")
let adaptive = #cssUIColor("#FFFFFF", "rgb(0, 0, 0)")
```

All of these are validated at compile time — a malformed literal is a build error, not a runtime fallback.

### `#localized`

Creates a `LocalizedStringResource` from a string literal, with an optional bundle:

```swift
let title      = #localized("welcome.title")            // bundle: .main
let fromModule = #localized("welcome.title", .module)
```

`.main` is emitted as the literal `bundle: .main` (and every other accessor through `bundle: .atURL(Bundle.<x>.bundleURL)`) — the two shapes Xcode's String Catalog extractor recognises, so keys declared this way are not tagged stale.

---

## Code Generation

### `@SoftCodable`

Generates `Codable` conformance with snake_case keys and **soft-fail decoding**: a missing key falls back to the property's inline default instead of throwing. Removes hand-written `CodingKeys` + `init(from:)` + `encode(to:)` from data-definition structs (rule manifests, settings, scenario files).

```swift
@SoftCodable
public struct Boundaries: Sendable, Hashable {
    public var rating: String = ""
    public var avoid: [String] = []
    public var note: String?
}
// Keys: "rating", "avoid", "note" — missing "avoid" decodes to [], missing "note" to nil.
```

Applies to a `struct` whose stored properties carry an explicit type. Decoding, per property:

| Property | On a missing key |
|----------|------------------|
| has an inline default | falls back to it |
| optional type | `nil` |
| non-optional, no default | required — throws |

`static` and computed properties are ignored. `init(from:)` / `encode(to:)` are emitted in an extension, and a memberwise `init` built from the same inline defaults is emitted as a member at the struct's access level — a `public` struct gets a `public` one, which the implicit memberwise initializer never is (it is `internal`, so it cannot be used as a default argument outside the module).

Key derivation reads a run of capitals as one word: `backendID` → `"backend_id"`, not `"backend_i_d"`.

**Helper macros:**

| Macro | Effect |
|-------|--------|
| `@SoftKey("...")` | Names the key outright, where no case boundary exists to read: `requiredPCID` → `"required_pc_id"`, `presentNPCs` → `"present_npcs"` |
| `@SoftRequired` | Keeps the key required on decode even though the property has an inline default — the default then serves only the generated initializer |
| `@SoftIgnore` | Skips the property entirely (neither encoded nor decoded); it must have an inline default, which it is set to on decode |

```swift
@SoftCodable
public struct Scenario: Sendable {
    @SoftRequired public var schemaVersion: Int = 3        // must be in the file
    @SoftKey("reveals_npc_ids") public var revealsNPCIds: [String] = []
    @SoftIgnore public var isDirty: Bool = false           // transient
}
```

### `@MemberwiseInit`

Generates a memberwise `init` for structs, at the struct's own access level.

| Property | Parameter |
|----------|-----------|
| `var x: T = value` | `x: T = value` — the default is preserved |
| `var x: T?` / `let x: T?` | `x: T? = nil` |
| `let x: T` | `x: T` — required |
| `let x: T = value` | none — an initialized constant cannot be assigned |

```swift
@MemberwiseInit
public struct UserProfile {
    public let name: String
    public let bio: String?
    public var greeting: String = "hi"
    public let createdAt: Date = .now
}
// Generates:
// public init(name: String, bio: String? = nil, greeting: String = "hi")
```

### `@StringRepresentable`

Generates `RawRepresentable` (and `StringRepresentableValue`) conformance with dot-separated string encoding for enums.

```swift
@StringRepresentable
enum Route {
    case home                     // "home"
    case settings(id: Int)        // "settings.42"
    case profile(name: String?)   // "profile" or "profile.john"
}
```

A simple case spells itself with its own name; an associated value is appended after a dot. An optional associated value omits the suffix when `nil`.

**The associated value must be `StringRepresentableValue`** — the protocol answering how a value spells itself and how it is read back. Two families conform for free: anything `LosslessStringConvertible` (`Int`, `Double`, `Bool`, `String`, …) and anything `RawRepresentable where RawValue == String`, another `@StringRepresentable` enum included. A type that is both must pick one itself.

**One value per case.** The encoding's only degree of freedom is its tail, so exactly one value may itself contain a dot; a case with two associated values is a compile error. Wrap them in a single value instead.

**Spelling** — `@StringRepresentable(.snakeCase)` writes case names as snake_case, for an enum riding in a document whose every other key is snake_case:

```swift
@StringRepresentable(.snakeCase)
enum Trigger {
    case scenarioStart        // "scenario_start"
    case countdownStep(Int)   // "countdown_step.2"
}
```

It is opt-in and has to be: `.caseName` (the default) produces raw values that are already written down — a theme in `@AppStorage`, an event kind in a store — and a spelling that changed under them would read back as nothing. The conversion is `@SoftCodable`'s, so a run of capitals stays one word.

### `@LoggersCollection`

Generates static `Logger` properties from a nested `Categories` enum. The subsystem is passed as a positional argument; if omitted, it's derived from the enum name with `Loggers` / `LoggersCollection` suffixes stripped.

```swift
@LoggersCollection("com.example.app")
enum AppLoggers {
    enum Categories {
        case network
        case storage
        case ui
    }
}
// Generates: static let network = Logger(subsystem: "com.example.app", category: "Network")
// etc. (category names are capitalized)
```

---

## Property Wrappers

### `@LazyAtomic`

Thread-safe lazy initialization using `NSLock`. The value is computed once on first access.

```swift
@LazyAtomic var heavyObject = HeavyObject()
```

### `@UserDefault`

Syncs a value with `UserDefaults`. Supports a custom `ValueTransformer` and publishes changes via a `CurrentValueSubject` exposed as `projectedValue`.

```swift
@UserDefault("user.onboarded", store: .standard) var hasOnboarded: Bool = false
```

`@CodableUserDefault` stores `Codable` types as JSON.

```swift
@CodableUserDefault("user.preferences", store: .standard) var preferences: UserPreferences? = nil
```

---

## Logging

`Camper.Logger` is a protocol-based wrapper over both SwiftyBeaver and OSLog. Configure once at app startup:

```swift
LoggerConfigurator.configure(
    writeLogFile: true,
    minimumLogLevel: .debug
)
```

`minimumLogLevel` accepts `Camper.LogLevel` (`.verbose`, `.debug`, `.info`, `.warning`, `.error`, `.critical`, `.fault`) — you don't need to import SwiftyBeaver to choose one.

### Per-category gating with environment variables

When `useEnvironmentVariables: true`, every log call is suppressed unless an environment variable named `<CATEGORY>_LOGS` is set in the process. The variable name is derived from the logger's `category` (uppercased). Useful for opting in to specific subsystems during debugging without touching code:

```swift
LoggerConfigurator.configure(useEnvironmentVariables: true, minimumLogLevel: .debug)

// In your scheme/launch environment, set NETWORK_LOGS=1 to allow only network logs.
```

### Error callback

`onError` fires for every `.error`/`.critical`/`.fault` message. Useful for forwarding to crash reporters:

```swift
LoggerConfigurator.configure(onError: { message in
    Crashlytics.crashlytics().log(message)
})
```

### File logs

When `writeLogFile: true`, logs are written to a `.log` file under `LoggerConfigurator.logsFolder` (defaults to `Application Support/logs`). Helpers:

- `LoggerConfigurator.flush()` — flush buffered output.
- `LoggerConfigurator.clearLogs()` — remove all log files (re-creates a fresh destination if file logging is enabled).
- `LoggerConfigurator.zipLogs()` — flush, archive the folder into a sibling `.zip`, return the archive URL.

---

## Operations

### `OperationExecutor`

An actor that runs `async`/`throws` operations identified by an `OperationID` and exposes their lifecycle as observable state.

```swift
let executor = OperationExecutor.shared
let id: OperationID = "user.login"

// Fire-and-forget: state is tracked under `id`.
executor.perform(id: id) {
    try await api.login(...)
}

// SwiftUI: drive a view from the operation's state.
let watcher = await executor.watcher(id: id)
// watcher.state transitions: .idle -> .inProgress -> .success | .failed(OperationError)
```

`OperationState`:
- `.idle`, `.inProgress`, `.success`
- `.failed(OperationError)` — `OperationError` is a `Sendable` wrapper around any thrown error, exposing `description` and `underlyingTypeName`.

`OperationExecutor` also exposes:
- `stream(id:)` — multicast `AsyncSequence` of states for `id` (each call returns its own subscription; multiple concurrent consumers are supported).
- `wait(id:)` — `async throws` until the operation reaches `.success` or `.failed`. Returns immediately if the operation already finished.

`perform(id:ignoreActive:operation:)` skips the call if the same `id` is currently `.inProgress`, unless `ignoreActive: true` is passed.

---

## Utilities

### `TaskQueue`

An actor limiting how many `async` operations run at once. `enqueue` suspends until a slot is free, then runs the operation and rethrows whatever it throws.

```swift
let queue = TaskQueue(concurrency: 2)
let result = try await queue.enqueue { try await importer.run(file) }
```

### `ObservationContainer` / `ObservationToken`

A lightweight, actor-backed observer registry. Observers are held **weakly** — keep the returned token alive for as long as you want the callback, and drop it to unsubscribe.

```swift
let container = ObservationContainer<Int>()
let token = container.addObserver { value in print(value) }   // retain me
await container.notifyObservers(value: 42)
```

`addObserver` and the `nonisolated` `notifyObservers` overloads are callable synchronously (they hop onto the actor themselves); from an `async` context the actor-isolated `notifyObservers(value:)` is picked, so it needs `await`. `Value == Void` also gets a no-argument `notifyObservers()`.

### `FolderMonitor` / `FileWatcher`

Watch a directory or a single file for changes. Both expose their state on the main actor, so SwiftUI can read it directly.

```swift
let monitor = FolderMonitor(url: folder)
monitor.startMonitoring()
// monitor.folderContent: [FilePathInfo] — @MainActor, updated on change
monitor.stopMonitoring()

// FileWatcher is @Observable and its init is @MainActor.
let watcher = FileWatcher(url: file)
watcher.startMonitoring()
// watcher.isExist, watcher.hashValue — both @MainActor
```

`FilePathInfo` is a `Sendable`, `Hashable`, `Identifiable` snapshot of one path: `isFolder`, `name`, `url`, `size`, `modificationDate`, `creationDate`. It identifies by value, so SwiftUI diffing notices a size or date change on an unchanged path.

---

## License

MIT
