/// Generates a memberwise `init` for a struct where optional stored properties
/// receive `= nil` as their default value.
///
/// Non-optional properties remain required. The generated `init` access level
/// matches the struct's declared access level.
///
/// ### Example:
/// ```swift
/// @MemberwiseInit
/// public struct Point {
///     public let x: Double
///     public let y: Double
///     public let label: String?
/// }
/// // Generates: public init(x: Double, y: Double, label: String? = nil)
/// ```
@attached(member, names: named(init))
public macro MemberwiseInit() = #externalMacro(module: "CamperMacros", type: "MemberwiseInit")
