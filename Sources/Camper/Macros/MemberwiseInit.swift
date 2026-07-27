/// Generates a memberwise `init` for a struct where optional stored properties
/// receive `= nil` as their default value, and properties with explicit defaults
/// preserve their initial values.
///
/// Non-optional properties without defaults remain required. The generated `init` access level
/// matches the struct's declared access level.
///
/// ### Example:
/// ```swift
/// @MemberwiseInit
/// public struct Config {
///     public let host: String
///     public let port: Int
///     public let label: String?
///     public let verbose: Bool = false
/// }
/// // Generates: public init(host: String, port: Int, label: String? = nil, verbose: Bool = false)
/// ```
@attached(member, names: named(init))
public macro MemberwiseInit() = #externalMacro(module: "CamperMacros", type: "MemberwiseInit")
