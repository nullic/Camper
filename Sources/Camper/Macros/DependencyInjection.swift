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
@attached(member, names: named(Outputs), named(Dependencies), named(dependencies), named(init()), named(init(dependencies:)), named(getValue()), named(subscript(dynamicMember:)))
@attached(extension, names: named(mocked), named(DependenciesMock), named(mock))
public macro Injector(mock: Bool = false, dependenciesMock: Bool = false) = #externalMacro(module: "CamperMacros", type: "Injector")

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
@attached(peer, names: suffixed(Mock))
public macro AutoMockable() = #externalMacro(module: "CamperMacros", type: "AutoMockable")

public protocol InjectorOutputs {}

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
}
