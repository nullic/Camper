/// Generates a memberwise `init` for a struct, at the struct's own access level.
///
/// - `var x: T = value` becomes `x: T = value` — the default is preserved;
/// - an optional property becomes `x: T? = nil`;
/// - `let x: T` stays required;
/// - `let x: T = value` gets no parameter at all — an initialized constant cannot be assigned.
///
/// ### Example:
/// ```swift
/// @MemberwiseInit
/// public struct Config {
///     public let host: String
///     public let port: Int
///     public let label: String?
///     public var verbose: Bool = false
///     public let createdAt: Date = .now
/// }
/// // Generates: public init(host: String, port: Int, label: String? = nil, verbose: Bool = false)
/// ```
@attached(member, names: named(init))
public macro MemberwiseInit() = #externalMacro(module: "CamperMacros", type: "MemberwiseInit")
