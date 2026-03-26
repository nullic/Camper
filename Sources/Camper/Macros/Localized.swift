import Foundation

/// Creates a `LocalizedStringResource` from a string literal.
///
/// - Parameters:
///   - stringLiteral: The localization key.
///   - bundle: Optional bundle containing the localization. Defaults to `.main`.
///
///     let greeting = #localized("hello_world")
///     let fromBundle = #localized("hello_world", .module)
@freestanding(expression)
public macro localized(_ stringLiteral: StringLiteralType, _ bundle: Bundle? = nil) -> LocalizedStringResource = #externalMacro(module: "CamperMacros", type: "LocalizedMacro")
