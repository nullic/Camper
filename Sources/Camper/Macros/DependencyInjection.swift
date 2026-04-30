/// Generates an implementation class (and optionally a mock) for a dependency injection protocol.
///
/// Apply to a protocol whose name ends with "Injection". Generates `<Name>Impl` class that
/// resolves dependencies from the injector, and optionally `<Name>Mock` and `build(injector:)`.
///
/// - Parameters:
///   - mock: Set to `false` to suppress `*Mock` generation. Default is `true`.
///   - build: Set to `true` to generate a `build(injector:)` factory function. Default is `false`.
///   - injectorType: Custom injector type. Defaults to `DefaultInjector`.
///
///     @Injection
///     protocol HomeInjection {
///         var analytics: AnalyticsService { get }
///         @Origin("settings.endpoint") var endpoint: String { get }
///     }
@attached(peer, names: suffixed(Impl), suffixed(Mock), named(build(injector:)))
public macro Injection(mock: Bool = true, build: Bool = false, injectorType: Any.Type? = nil) = #externalMacro(module: "CamperMacros", type: "Injection")

/// Generates the dependency injector infrastructure for a class.
///
/// Creates `DefaultInjector` typealias, `Dependencies` and `Outputs` protocols,
/// initializers, and `getValue()` accessors. Optionally generates mock types.
///
/// - Parameters:
///   - mock: Set to `true` to generate a mock injector. Default is `false`.
///   - dependenciesMock: Set to `true` to generate a `DependenciesMock` class. Default is `false`.
///
///     @Injector(mock: true, dependenciesMock: true)
///     class AppInjector {
///         @Dependency var api: APIService
///         @Dependency(.explicit) var settings: AppSettings
///         @Output var router: Router
///     }
@attached(peer, names: named(DefaultInjector), suffixed(Mock))
@attached(member, names: arbitrary)
@attached(extension, names: named(mocked), named(DependenciesMock), named(mock))
public macro Injector(mock: Bool = true, dependenciesMock: Bool = true) = #externalMacro(module: "CamperMacros", type: "Injector")

/// Marks a property as a dependency resolved from the injector's `Dependencies`.
///
/// Generates a `get` accessor that reads from `dependencies.<propertyName>`.
///
/// **Explicit** (`@Dependency(.explicit)`): the property becomes an extra `init` parameter
/// stored in `_ExplicitDependencies` — not part of the `Dependencies` protocol:
/// ```swift
/// @Dependency(.explicit) var settings: AppSettings
/// @Dependency(.explicit) var features: AppFeatures
/// ```
///
///     @Dependency
///     var api: APIService
@attached(peer)
@attached(accessor)
public macro Dependency(_ mode: DependencyMode? = nil) = #externalMacro(module: "CamperMacros", type: "Dependency")

/// Marks a property to be exposed via the injector's `Outputs` protocol.
///
/// Use `.internal` to restrict visibility, `.subscript` to generate a dynamic member lookup.
///
///     @Output
///     var router: Router
@attached(peer)
public macro Output(_ options: OutputOption...) = #externalMacro(module: "CamperMacros", type: "Output")

/// Marks an optional property for passing objects through the injection chain.
///
/// The property is stored as a weak reference and can be retrieved by child injections
/// via `PassedObjectsInjection.getPassedObject()`.
///
///     @Passed
///     var coordinator: Coordinator?
@attached(peer)
public macro Passed() = #externalMacro(module: "CamperMacros", type: "Passed")

/// Overrides the injector key path for a property in an `@Injection` protocol.
///
/// Specify a dot-separated path relative to `injector`:
/// ```swift
/// @Origin("analytics.tracker") var tracker: Tracker { get }
/// // Generates: var tracker: Tracker { injector.analytics.tracker }
/// ```
@attached(peer)
public macro Origin(_ path: String) = #externalMacro(module: "CamperMacros", type: "Origin")

/// Generates a `*Mock` class with full call tracking for a protocol.
///
/// For each method generates: call count, received arguments, invocations array,
/// return value, throwable error, and closure for custom implementation.
///
/// For properties: optional → `nil` default, non-optional → backing `underlying*` property.
///
/// If the protocol is `public`, the mock and all members are also `public`.
///
/// ### Example:
/// ```swift
/// @AutoMockable
/// protocol AuthRepository {
///     func login(email: String, password: String) async throws
/// }
/// // Generates AuthRepositoryMock with loginEmailStringPasswordString* tracking properties
/// ```
///
/// ### Known limitations
/// - Generated member names embed each parameter's label and type, so they are
///   long and hard to predict. Use `@MockName("...")` on a method to override
///   the auto-generated prefix when the inferred name is too long or collides.
/// - `@MainActor` and complex async/throws combinations are not yet covered by
///   macro-level tests; treat them as unverified until you exercise them in your
///   own test suite.
@attached(peer, names: suffixed(Mock))
public macro AutoMockable() = #externalMacro(module: "CamperMacros", type: "AutoMockable")

/// Overrides the prefix used for the generated mock members of one method
/// inside an `@AutoMockable` protocol.
///
/// By default `@AutoMockable` builds a unique prefix from the method name and
/// each parameter's label/type, which can be long and overload-sensitive.
/// `@MockName("login")` makes the generated members use `login` as the prefix:
/// `loginCallsCount`, `loginReceivedArguments`, `loginClosure`, etc.
///
/// The override is applied verbatim — collisions between two methods with the
/// same `@MockName` will produce a duplicate-symbol error at compile time.
///
///     @AutoMockable
///     protocol AuthRepository {
///         @MockName("login")
///         func login(email: String, password: String) async throws
///     }
@attached(peer)
public macro MockName(_ name: String) = #externalMacro(module: "CamperMacros", type: "MockName")

public enum DependencyMode {
    /// The dependency is passed explicitly as an `init` parameter and stored in `_ExplicitDependencies`,
    /// rather than being resolved from the `Dependencies` protocol.
    case explicit
    /// Generates a `@dynamicMemberLookup` subscript for the dependency type on the enclosing `@Injector` class.
    case `subscript`
}

public enum OutputOption {
    case `internal`
    case `subscript`
}


public final class WeakRef {
    public weak var value: AnyObject?
    public init(_ value: AnyObject?) {
        self.value = value
    }
}

public protocol PassedObjectsInjection: AnyObject {
    func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject
    func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject
}
