import SwiftData

/// Generates an input/output model layer for a SwiftData class.
///
/// Adds the following members:
/// - `InputModel` protocol with all stored properties
/// - `Snapshot` struct conforming to `InputModel`, `Codable`, and `Sendable`
/// - `init(input:context:)` initializer from `InputModel`
/// - `update(input:)` method for updating the model
/// - `snapshot(includeLinks:)` for creating a codable snapshot
/// - `UniqueFindable` conformance if an `@Attribute(.unique)` property exists
/// - `unique(_:in:)`, `delete(_:in:)`, `insert(_:in:)` class methods
///
/// For `@Relationship` properties, generates an `Input` enum with cases:
/// `.ignore`, `.value`, `.input`, and `.link` (unless `@NonLinkable`).
///
///     @Model @IOModel
///     class User {
///         @Attribute(.unique) var id: UUID
///         var name: String
///         @Relationship var profile: Profile
///     }
@attached(extension, conformances: UniqueFindable, names: arbitrary)
@attached(member, names: arbitrary, named(init))
public macro IOModel() = #externalMacro(module: "CamperMacros", type: "IOModel")

/// Marks a `@Relationship` property as virtual (computed) within an `@IOModel` class.
///
/// Virtual properties are excluded from the generated `init(input:context:)` and `update(input:)`.
@attached(peer)
public macro Virtual() = #externalMacro(module: "CamperMacros", type: "IOAttribute")

/// Prevents the `.link` case from being generated for a `@Relationship` property's input enum.
///
/// Use this when a relationship should not be resolved by unique ID lookup.
@attached(peer)
public macro NonLinkable() = #externalMacro(module: "CamperMacros", type: "IOAttribute")

/// Makes a regular (non-relationship) property optional during input by generating
/// an enum with `.ignore` and `.value` cases instead of requiring a direct value.
///
/// Use this for partial updates where some fields can be skipped.
///
///     @Model @IOModel
///     class User {
///         var name: String
///         @Ignorable var nickname: String
///     }
@attached(peer)
public macro Ignorable() = #externalMacro(module: "CamperMacros", type: "IOAttribute")

@available(iOS 17, *)
public protocol UniqueFindable {
    associatedtype UniqueID
    var uniqueValue: UniqueID { get }

    static func unique(_ value: UniqueID, in context: ModelContext) throws -> Self?
}
