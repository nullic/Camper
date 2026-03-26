import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CamperMacros

final class HexColorMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "hexColor": HexColorMacro.self,
        "hexUIColor": HexColorMacro.self,
        "hexNSColor": HexColorMacro.self,
    ]

    // MARK: - #hexColor

    func testHexColorFromString6Digit() {
        assertMacroExpansion(
            """
            let color = #hexColor("FF0000")
            """,
            expandedSource: """
            let color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexColorFromInteger() {
        assertMacroExpansion(
            """
            let color = #hexColor(0x00FF00)
            """,
            expandedSource: """
            let color = Color(red: 0.0, green: 1.0, blue: 0.0, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexColorFromString8Digit() {
        assertMacroExpansion(
            """
            let color = #hexColor("0000FFFF")
            """,
            expandedSource: """
            let color = Color(red: 0.0, green: 0.0, blue: 1.0, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexColorWithHashPrefix() {
        assertMacroExpansion(
            """
            let color = #hexColor("#FF0000")
            """,
            expandedSource: """
            let color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    // MARK: - #hexUIColor

    func testHexUIColorSingle() {
        assertMacroExpansion(
            """
            let color = #hexUIColor("FF0000")
            """,
            expandedSource: """
            let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexUIColorSingleInteger() {
        assertMacroExpansion(
            """
            let color = #hexUIColor(0x0000FF)
            """,
            expandedSource: """
            let color = UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexUIColorLightDarkStrings() {
        assertMacroExpansion(
            """
            let color = #hexUIColor("FF0000", "0000FF")
            """,
            expandedSource: """
            let color = UIColor {
                $0.userInterfaceStyle == .light ? UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) : UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            }
            """,
            macros: testMacros
        )
    }

    func testHexUIColorLightDarkIntegers() {
        assertMacroExpansion(
            """
            let color = #hexUIColor(0xFF0000, 0x0000FF)
            """,
            expandedSource: """
            let color = UIColor {
                $0.userInterfaceStyle == .light ? UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) : UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - #hexNSColor

    func testHexNSColorSingle() {
        assertMacroExpansion(
            """
            let color = #hexNSColor("FF0000")
            """,
            expandedSource: """
            let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexNSColorLightDark() {
        assertMacroExpansion(
            """
            let color = #hexNSColor("FF0000", "0000FF")
            """,
            expandedSource: """
            let color = NSColor(name: nil) {
                $0.name == .aqua ? NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) : NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Error cases

    func testHexColorInvalidFormat() {
        assertMacroExpansion(
            """
            let color = #hexColor("GG")
            """,
            expandedSource: """
            let color = #hexColor("GG")
            """,
            diagnostics: [
                DiagnosticSpec(message: "#hexColor accept only next formats: '#rgb' '#rgba' '#rrggbb' '#rrggbbaa' '0xrgb' '0xrgba' '0xrrggbb' '0xrrggbbaa'", line: 1, column: 13),
            ],
            macros: testMacros
        )
    }
}
