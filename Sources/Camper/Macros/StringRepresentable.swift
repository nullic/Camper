/// Generates `RawRepresentable` conformance with dot-separated string encoding for enums.
///
/// Simple cases use their name as the raw value. Cases with associated values encode them
/// after a dot separator, so an associated value must be `StringRepresentableValue` — every
/// standard-library value that reads back from its own spelling is, and so is any other
/// `@StringRepresentable` enum. Optional associated values omit the suffix when `nil`.
///
/// The generated code used to ask the associated value for a `rawValue` outright, which
/// neither `Int` nor `String` has — the very two the examples below use. It went unnoticed
/// because the macro's tests compared the expansion as text and never compiled it;
/// `CamperTests` uses the macro for real now.
///
///     @StringRepresentable
///     enum Route {
///         case home                     // "home"
///         case settings(id: Int)        // "settings.42"
///         case profile(name: String?)   // "profile" or "profile.john"
///     }
/// How a case spells itself in the string.
public enum StringRepresentableNaming: Sendable {
    /// The case's own name — `largeTitle` → `"largeTitle"`.
    ///
    /// The default, and it has to be: these raw values are already written down — a theme in
    /// `@AppStorage`, an event kind in a store — and a spelling that changed under them would
    /// read back as nothing.
    case caseName

    /// snake_case, the spelling `@SoftCodable` gives a property — `countdownStep` →
    /// `"countdown_step"`.
    ///
    /// For an enum that rides in a document whose every other key is snake_case.
    case snakeCase
}

@attached(extension, conformances: RawRepresentable, StringRepresentableValue, names: named(rawValue), named(init(rawValue:)))
public macro StringRepresentable(_ naming: StringRepresentableNaming = .caseName) = #externalMacro(module: "CamperMacros", type: "StringRepresentableMacro")
