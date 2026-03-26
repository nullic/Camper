/// Generates `RawRepresentable` conformance with dot-separated string encoding for enums.
///
/// Simple cases use their name as the raw value. Cases with associated values
/// encode them after a dot separator using the value's own `rawValue`.
/// Optional associated values omit the suffix when `nil`.
///
///     @StringRepresentable
///     enum Route {
///         case home                     // "home"
///         case settings(id: Int)        // "settings.42"
///         case profile(name: String?)   // "profile" or "profile.john"
///     }
@attached(extension, conformances: RawRepresentable, names: named(rawValue), named(init(rawValue:)))
public macro StringRepresentable() = #externalMacro(module: "CamperMacros", type: "StringRepresentableMacro")
