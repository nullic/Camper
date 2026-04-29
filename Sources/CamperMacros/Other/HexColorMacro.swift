import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HexColorMacro: ExpressionMacro {
    public static func expansion(of node: some SwiftSyntax.FreestandingMacroExpansionSyntax,
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> SwiftSyntax.ExprSyntax
    {
        guard let argument = node.arguments.first else { fatalError("macro needs an value") }
        let macroName = node.macroName.description
        let (red, green, blue, opacity) = try scan(argument: argument, macroName: macroName)

        if macroName == "hexUIColor" || macroName == "cssUIColor" {
            let lightString = "UIColor(red: \(red), green: \(green), blue: \(blue), alpha: \(opacity))"

            if node.arguments.count > 1, let argument = node.arguments.last {
                let (red2, green2, blue2, opacity2) = try scan(argument: argument, macroName: macroName)
                let darkString = "UIColor(red: \(red2), green: \(green2), blue: \(blue2), alpha: \(opacity2))"
                return "UIColor { $0.userInterfaceStyle == .light ? \(raw: lightString) : \(raw: darkString) }"
            } else {
                return "\(raw: lightString)"
            }
        } else if macroName == "hexNSColor" || macroName == "cssNSColor" {
            let lightString = "NSColor(red: \(red), green: \(green), blue: \(blue), alpha: \(opacity))"

            if node.arguments.count > 1, let argument = node.arguments.last {
                let (red2, green2, blue2, opacity2) = try scan(argument: argument, macroName: macroName)
                let darkString = "NSColor(red: \(red2), green: \(green2), blue: \(blue2), alpha: \(opacity2))"
                return " NSColor(name: nil) { $0.name == .aqua ? \(raw: lightString) : \(raw: darkString) }"
            } else {
                return "\(raw: lightString)"
            }

        } else {
            return "Color(red: \(raw: red), green: \(raw: green), blue: \(raw: blue), opacity: \(raw: opacity))"
        }
    }

    private static func scan(argument: LabeledExprSyntax, macroName: String) throws -> (Double, Double, Double, Double) {
        let raw = "\(argument)"
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespaces)

        if macroName.hasPrefix("css") {
            let lower = raw.lowercased()
            if lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(") {
                return try scanRGBA(raw)
            }
        }

        return try scanHex(raw)
    }

    private static func scanHex(_ input: String) throws -> (Double, Double, Double, Double) {
        let hexString = input
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
            let r = (hexValue & 0x0F00) >> 8
            let g = (hexValue & 0x00F0) >> 4
            let b = (hexValue & 0x000F) >> 0
            red = Double((r << 4) | r) / 255.0
            green = Double((g << 4) | g) / 255.0
            blue = Double((b << 4) | b) / 255.0
            opacity = 1.0

        case 4: // RGBA
            let r = (hexValue & 0xF000) >> 12
            let g = (hexValue & 0x0F00) >> 8
            let b = (hexValue & 0x00F0) >> 4
            let a = (hexValue & 0x000F) >> 0
            red = Double((r << 4) | r) / 255.0
            green = Double((g << 4) | g) / 255.0
            blue = Double((b << 4) | b) / 255.0
            opacity = Double((a << 4) | a) / 255.0

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
            throw CamperMacrosError.hexColorInvalidValue
        }

        return (red, green, blue, opacity)
    }

    private static func scanRGBA(_ input: String) throws -> (Double, Double, Double, Double) {
        guard let openParen = input.firstIndex(of: "("),
              let closeParen = input.lastIndex(of: ")"),
              openParen < closeParen
        else {
            throw CamperMacrosError.cssColorInvalidValue
        }

        let inner = input[input.index(after: openParen) ..< closeParen]
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        switch parts.count {
        case 3:
            guard let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) else {
                throw CamperMacrosError.cssColorInvalidValue
            }
            return (r / 255.0, g / 255.0, b / 255.0, 1.0)

        case 4:
            guard let r = Double(parts[0]), let g = Double(parts[1]),
                  let b = Double(parts[2]), let a = Double(parts[3])
            else {
                throw CamperMacrosError.cssColorInvalidValue
            }
            return (r / 255.0, g / 255.0, b / 255.0, a)

        default:
            throw CamperMacrosError.cssColorInvalidValue
        }
    }
}
