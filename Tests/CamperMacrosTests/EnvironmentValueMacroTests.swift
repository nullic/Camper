import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CamperMacros

final class EnvironmentValueMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "EnvironmentValue": EnvironmentValueMacro.self,
    ]

    func testEnvironmentValueWithDefault() {
        assertMacroExpansion(
            """
            @EnvironmentValue
            var myValue: String = "hello"
            """,
            expandedSource: """
            var myValue: String {
                get {
                    self[__Key_myValue.self]
                }
                set {
                    self[__Key_myValue.self] = newValue
                }
            }

            private struct __Key_myValue: SwiftUI.EnvironmentKey {
                static let defaultValue: String = "hello"
            }
            """,
            macros: testMacros
        )
    }

    func testEnvironmentValueOptional() {
        assertMacroExpansion(
            """
            @EnvironmentValue
            var myValue: String?
            """,
            expandedSource: """
            var myValue: String? {
                get {
                    self[__Key_myValue.self]
                }
                set {
                    self[__Key_myValue.self] = newValue
                }
            }

            private struct __Key_myValue: SwiftUI.EnvironmentKey {
                static let defaultValue: String? = nil
            }
            """,
            macros: testMacros
        )
    }
}
