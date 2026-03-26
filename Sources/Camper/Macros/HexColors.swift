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

public extension Color {
    init?(hexString: String) {
        guard let (red, green, blue, opacity) = scan(hexString: hexString) else { return nil }
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}

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

    public extension UIColor {
        convenience init?(hexString: String) {
            guard let (red, green, blue, alpha) = scan(hexString: hexString) else { return nil }
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        }
    }

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

    public extension NSColor {
        convenience init?(hexString: String) {
            guard let (red, green, blue, alpha) = scan(hexString: hexString) else { return nil }
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        }
    }

#endif

private func scan(hexString: String) -> (Double, Double, Double, Double)? {
    let hexString = hexString
        .replacingOccurrences(of: "\"", with: "")
        .replacingOccurrences(of: "#", with: "")
        .replacingOccurrences(of: "0x", with: "")
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: " ", with: "")

    let scanner = Scanner(string: hexString)
    var hexValue: UInt64 = 0
    scanner.scanHexInt64(&hexValue)

    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    switch hexString.count {
    case 3: // RGB
        red = Double((hexValue & 0x0F00) >> 8) / 255.0
        green = Double((hexValue & 0x00F0) >> 4) / 255.0
        blue = Double((hexValue & 0x000F) >> 0) / 255.0
        opacity = 1.0

    case 4: // RGBA
        red = Double((hexValue & 0xF000) >> 12) / 255.0
        green = Double((hexValue & 0x0F00) >> 8) / 255.0
        blue = Double((hexValue & 0x00F0) >> 4) / 255.0
        opacity = Double((hexValue & 0x000F) >> 0) / 255.0

    case 6: // RRGGBB
        red = Double((hexValue & 0x00FF_0000) >> 16) / 255.0
        green = Double((hexValue & 0x0000_FF00) >> 8) / 255.0
        blue = Double((hexValue & 0x0000_00FF) >> 0) / 255.0
        opacity = 1.0

    case 8: // RRGGBBAA
        red = Double((hexValue & 0xFF00_0000) >> 24) / 255.0
        green = Double((hexValue & 0x00FF_0000) >> 16) / 255.0
        blue = Double((hexValue & 0x0000_FF00) >> 8) / 255.0
        opacity = Double((hexValue & 0x0000_00FF) >> 0) / 255.0

    default:
        return nil
    }

    return (red, green, blue, opacity)
}
