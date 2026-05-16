import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CamperMacros

final class HexColorMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "hexColor": HexColorMacro.self,
        "hexUIColor": HexColorMacro.self,
        "hexNSColor": HexColorMacro.self,
        "cssColor": HexColorMacro.self,
        "cssUIColor": HexColorMacro.self,
        "cssNSColor": HexColorMacro.self,
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

    func testHexColorFromString3Digit() {
        assertMacroExpansion(
            """
            let color = #hexColor("F00")
            """,
            expandedSource: """
            let color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexColorFromString4Digit() {
        assertMacroExpansion(
            """
            let color = #hexColor("0F0F")
            """,
            expandedSource: """
            let color = Color(red: 0.0, green: 1.0, blue: 0.0, opacity: 1.0)
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
                $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0) : NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            }
            """,
            macros: testMacros
        )
    }

    func testHexColorLightDarkStrings() {
        assertMacroExpansion(
            """
            let color = #hexColor("FF0000", "0000FF")
            """,
            expandedSource: """
            let color = {
                #if canImport(UIKit)
                return Color(uiColor: UIColor {
                        $0.userInterfaceStyle == .light ? UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) : UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
                    })
                #elseif canImport(AppKit)
                return Color(nsColor: NSColor(name: nil) {
                        $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0) : NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
                    })
                #else
                return Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)
                #endif
            }()
            """,
            macros: testMacros
        )
    }

    func testHexColorLightDarkIntegers() {
        assertMacroExpansion(
            """
            let color = #hexColor(0xFF0000, 0x0000FF)
            """,
            expandedSource: """
            let color = {
                #if canImport(UIKit)
                return Color(uiColor: UIColor {
                        $0.userInterfaceStyle == .light ? UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) : UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
                    })
                #elseif canImport(AppKit)
                return Color(nsColor: NSColor(name: nil) {
                        $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0) : NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
                    })
                #else
                return Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)
                #endif
            }()
            """,
            macros: testMacros
        )
    }

    // MARK: - #cssColor

    func testCssColorFromHex() {
        assertMacroExpansion(
            """
            let color = #cssColor("#FF0000")
            """,
            expandedSource: """
            let color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testCssColorFromShortHex() {
        assertMacroExpansion(
            """
            let color = #cssColor("#F00")
            """,
            expandedSource: """
            let color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testCssColorFromRGB() {
        assertMacroExpansion(
            """
            let color = #cssColor("rgb(255, 0, 0)")
            """,
            expandedSource: """
            let color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testCssColorFromRGBA() {
        assertMacroExpansion(
            """
            let color = #cssColor("rgba(0, 255, 0, 0.5)")
            """,
            expandedSource: """
            let color = Color(red: 0.0, green: 1.0, blue: 0.0, opacity: 0.5)
            """,
            macros: testMacros
        )
    }

    func testCssUIColorFromRGBA() {
        assertMacroExpansion(
            """
            let color = #cssUIColor("rgba(0, 0, 255, 1)")
            """,
            expandedSource: """
            let color = UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            """,
            macros: testMacros
        )
    }

    func testCssUIColorLightDarkMixed() {
        assertMacroExpansion(
            """
            let color = #cssUIColor("#FFFFFF", "rgb(0, 0, 0)")
            """,
            expandedSource: """
            let color = UIColor {
                $0.userInterfaceStyle == .light ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0) : UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
            }
            """,
            macros: testMacros
        )
    }

    func testCssNSColorSingle() {
        assertMacroExpansion(
            """
            let color = #cssNSColor("rgb(255, 0, 0)")
            """,
            expandedSource: """
            let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            """,
            macros: testMacros
        )
    }

    func testCssNSColorLightDarkMixed() {
        assertMacroExpansion(
            """
            let color = #cssNSColor("#FFFFFF", "rgb(0, 0, 0)")
            """,
            expandedSource: """
            let color = NSColor(name: nil) {
                $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0) : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Edge cases — bit extraction

    func testHexColor3DigitMixedNibbles() {
        // "369" -> R=0x33=51, G=0x66=102, B=0x99=153 -> 0.2, 0.4, 0.6
        assertMacroExpansion(
            """
            let color = #hexColor("369")
            """,
            expandedSource: """
            let color = Color(red: 0.2, green: 0.4, blue: 0.6, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexColor3DigitAllChannelsDistinct() {
        // "036" -> R=0, G=0x33=51, B=0x66=102 -> 0.0, 0.2, 0.4
        assertMacroExpansion(
            """
            let color = #hexColor("036")
            """,
            expandedSource: """
            let color = Color(red: 0.0, green: 0.2, blue: 0.4, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexColor3DigitWithHashPrefix() {
        assertMacroExpansion(
            """
            let color = #hexColor("#369")
            """,
            expandedSource: """
            let color = Color(red: 0.2, green: 0.4, blue: 0.6, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexColor3DigitLowercase() {
        // "606" lowercase -> R=B=0x66=102, G=0 -> 0.4, 0.0, 0.4
        assertMacroExpansion(
            """
            let color = #hexColor("606")
            """,
            expandedSource: """
            let color = Color(red: 0.4, green: 0.0, blue: 0.4, opacity: 1.0)
            """,
            macros: testMacros
        )
    }

    func testHexColor4DigitMixedNibbles() {
        // "39C6" -> R=0x33=51, G=0x99=153, B=0xCC=204, A=0x66=102 -> 0.2, 0.6, 0.8, 0.4
        assertMacroExpansion(
            """
            let color = #hexColor("39C6")
            """,
            expandedSource: """
            let color = Color(red: 0.2, green: 0.6, blue: 0.8, opacity: 0.4)
            """,
            macros: testMacros
        )
    }

    func testHexColor6DigitNonTrivial() {
        // "33CC99" -> R=51, G=204, B=153 -> 0.2, 0.8, 0.6
        assertMacroExpansion(
            """
            let color = #hexColor("33CC99")
            """,
            expandedSource: """
            let color = Color(red: 0.2, green: 0.8, blue: 0.6, opacity: 1.0)
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

    func testCssColorInvalidFormat() {
        assertMacroExpansion(
            """
            let color = #cssColor("rgb(bad)")
            """,
            expandedSource: """
            let color = #cssColor("rgb(bad)")
            """,
            diagnostics: [
                DiagnosticSpec(message: "#cssColor accept only next formats: '#rgb' '#rgba' '#rrggbb' '#rrggbbaa' 'rgb(r, g, b)' 'rgba(r, g, b, a)'", line: 1, column: 13),
            ],
            macros: testMacros
        )
    }
}
