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
        let (red, green, blue, opacity) = try scan(argument: argument)

        if node.macroName.description == "hexUIColor" {
            let lightString = "UIColor(red: \(red), green: \(green), blue: \(blue), alpha: \(opacity))"

            if node.arguments.count > 1, let argument = node.arguments.last {
                let (red2, green2, blue2, opacity2) = try scan(argument: argument)
                let darkString = "UIColor(red: \(red2), green: \(green2), blue: \(blue2), alpha: \(opacity2))"
                return "UIColor { $0.userInterfaceStyle == .light ? \(raw: lightString) : \(raw: darkString) }"
            } else {
                return "\(raw: lightString)"
            }
        } else if node.macroName.description == "hexNSColor" {
            let lightString = "NSColor(red: \(red), green: \(green), blue: \(blue), alpha: \(opacity))"

            if node.arguments.count > 1, let argument = node.arguments.last {
                let (red2, green2, blue2, opacity2) = try scan(argument: argument)
                let darkString = "NSColor(red: \(red2), green: \(green2), blue: \(blue2), alpha: \(opacity2))"
                return " NSColor(name: nil) { $0.name == .aqua ? \(raw: lightString) : \(raw: darkString) }"
            } else {
                return "\(raw: lightString)"
            }

        } else {
            return "Color(red: \(raw: red), green: \(raw: green), blue: \(raw: blue), opacity: \(raw: opacity))"
        }
    }

    private static func scan(argument: LabeledExprSyntax) throws -> (Double, Double, Double, Double) {
        let hexString = "\(argument)"
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
            throw CamperMacrosError.hexColorInvalidValue
        }

        return (red, green, blue, opacity)
    }
}
