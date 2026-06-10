/// Generates `Codable` conformance with snake_case keys and **soft-fail decoding** —
/// a missing key falls back to the property's inline default. Removes the
/// hand-written `CodingKeys` + `init(from:)` (+ `encode(to:)`) boilerplate from
/// data-definition structs (rule manifests, settings, etc.).
///
/// Requirements: applied to a `struct` whose stored properties have an **explicit
/// type and inline default** (`var x: String = ""`). Because the generated members
/// live in an extension, the struct keeps its free implicit memberwise initializer.
///
/// Decoding rules per stored property:
/// - has an inline default → missing key falls back to it (`?? default`);
/// - optional type → missing key decodes to `nil`;
/// - non-optional without a default → required (throws if the key is missing).
///
/// `static` and computed properties are ignored. Mark a stored non-`Codable` or
/// transient property with `@SoftIgnore` (it must have an inline default).
///
/// ### Example
/// ```swift
/// @SoftCodable
/// public struct Boundaries: Sendable, Hashable {
///     public var rating: String = ""
///     public var avoid: [String] = []
/// }
/// // Author writes no `: Codable`, no CodingKeys, no init(from:)/encode(to:).
/// ```
@attached(extension, conformances: Codable, names: named(init(from:)), named(encode(to:)), named(CodingKeys))
public macro SoftCodable() = #externalMacro(module: "CamperMacros", type: "SoftCodable")

/// Marks a stored property to be skipped by `@SoftCodable` (neither encoded nor
/// decoded). The property must carry an inline default; on decode it is set to
/// that default. Use for transient or non-`Codable` state.
@attached(peer)
public macro SoftIgnore() = #externalMacro(module: "CamperMacros", type: "SoftIgnore")
