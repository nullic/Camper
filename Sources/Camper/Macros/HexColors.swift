import SwiftUI

/// Creates a `Color` from a hex string literal.
///
/// Supports 3 (RGB), 4 (RGBA), 6 (RRGGBB), and 8 (RRGGBBAA) digit formats.
/// The `#` and `0x` prefixes are optional.
///
///     let red = #hexColor("FF0000")
///     let semiTransparent = #hexColor("#FF000080")
@freestanding(expression)
public macro hexColor(_ stringLiteral: StringLiteralType) -> Color = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

/// Creates a `Color` from a hex integer literal.
///
///     let red = #hexColor(0xFF0000)
@freestanding(expression)
public macro hexColor(_ hexadecimalIntegerLiteral: IntegerLiteralType) -> Color = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

/// Creates a `Color` from a CSS-style string literal.
///
/// Supports hex (`#FFF`, `#FFFF`, `#FFFFFF`, `#FFFFFFFF`), `rgb(r, g, b)`,
/// and `rgba(r, g, b, a)` formats. R/G/B are 0...255, alpha is 0...1.
///
///     let red = #cssColor("#FF0000")
///     let green = #cssColor("rgb(0, 255, 0)")
///     let semiBlue = #cssColor("rgba(0, 0, 255, 0.5)")
@freestanding(expression)
public macro cssColor(_ stringLiteral: StringLiteralType) -> Color = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

#if canImport(UIKit)
    /// Creates a dynamic `UIColor` that adapts to light/dark mode using hex string literals.
    ///
    ///     let adaptive = #hexUIColor("FFFFFF", "000000")
    @freestanding(expression)
    public macro hexUIColor(_ light: StringLiteralType, _ dark: StringLiteralType) -> UIColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates a dynamic `UIColor` that adapts to light/dark mode using hex integer literals.
    ///
    ///     let adaptive = #hexUIColor(0xFFFFFF, 0x000000)
    @freestanding(expression)
    public macro hexUIColor(_ hexLight: IntegerLiteralType, _ hexDark: IntegerLiteralType) -> UIColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates a `UIColor` from a hex string literal.
    ///
    ///     let red = #hexUIColor("FF0000")
    @freestanding(expression)
    public macro hexUIColor(_ stringLiteral: StringLiteralType) -> UIColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates a `UIColor` from a hex integer literal.
    ///
    ///     let red = #hexUIColor(0xFF0000)
    @freestanding(expression)
    public macro hexUIColor(_ hexadecimalIntegerLiteral: IntegerLiteralType) -> UIColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates a `UIColor` from a CSS-style string literal.
    ///
    ///     let red = #cssUIColor("#FF0000")
    ///     let green = #cssUIColor("rgb(0, 255, 0)")
    ///     let semiBlue = #cssUIColor("rgba(0, 0, 255, 0.5)")
    @freestanding(expression)
    public macro cssUIColor(_ stringLiteral: StringLiteralType) -> UIColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates a dynamic `UIColor` that adapts to light/dark mode using CSS-style string literals.
    ///
    ///     let adaptive = #cssUIColor("#FFFFFF", "rgb(0, 0, 0)")
    @freestanding(expression)
    public macro cssUIColor(_ light: StringLiteralType, _ dark: StringLiteralType) -> UIColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

#endif

#if canImport(AppKit)
    /// Creates a dynamic `NSColor` that adapts to light/dark appearance using hex string literals.
    ///
    ///     let adaptive = #hexNSColor("FFFFFF", "000000")
    @freestanding(expression)
    public macro hexNSColor(_ light: StringLiteralType, _ dark: StringLiteralType) -> NSColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates a dynamic `NSColor` that adapts to light/dark appearance using hex integer literals.
    ///
    ///     let adaptive = #hexNSColor(0xFFFFFF, 0x000000)
    @freestanding(expression)
    public macro hexNSColor(_ hexLight: IntegerLiteralType, _ hexDark: IntegerLiteralType) -> NSColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates an `NSColor` from a hex string literal.
    ///
    ///     let red = #hexNSColor("FF0000")
    @freestanding(expression)
    public macro hexNSColor(_ stringLiteral: StringLiteralType) -> NSColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates an `NSColor` from a hex integer literal.
    ///
    ///     let red = #hexNSColor(0xFF0000)
    @freestanding(expression)
    public macro hexNSColor(_ hexadecimalIntegerLiteral: IntegerLiteralType) -> NSColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates an `NSColor` from a CSS-style string literal.
    ///
    ///     let red = #cssNSColor("#FF0000")
    ///     let green = #cssNSColor("rgb(0, 255, 0)")
    ///     let semiBlue = #cssNSColor("rgba(0, 0, 255, 0.5)")
    @freestanding(expression)
    public macro cssNSColor(_ stringLiteral: StringLiteralType) -> NSColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

    /// Creates a dynamic `NSColor` that adapts to light/dark appearance using CSS-style string literals.
    ///
    ///     let adaptive = #cssNSColor("#FFFFFF", "rgb(0, 0, 0)")
    @freestanding(expression)
    public macro cssNSColor(_ light: StringLiteralType, _ dark: StringLiteralType) -> NSColor = #externalMacro(module: "CamperMacros", type: "HexColorMacro")

#endif
