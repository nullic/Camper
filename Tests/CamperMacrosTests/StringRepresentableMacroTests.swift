import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CamperMacros

final class StringRepresentableMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "StringRepresentable": StringRepresentableMacro.self,
    ]

    func testSimpleCases() {
        assertMacroExpansion(
            """
            @StringRepresentable
            enum Route {
                case home
                case settings
            }
            """,
            expandedSource: """
            enum Route {
                case home
                case settings
            }

            extension Route: RawRepresentable, StringRepresentableValue {
                internal var rawValue: String {
                    switch self {
                    case .home:
                        return "home"
                    case .settings:
                        return "settings"
                    }
                }
                internal init?(rawValue: String) {
                    let components = rawValue.components(separatedBy: ".")
                    let firstComponent = components[0]
                    switch firstComponent {
                    case "home":
                        self = .home
                    case "settings":
                        self = .settings
                    default:
                        return nil
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testCaseWithAssociatedValue() {
        assertMacroExpansion(
            """
            @StringRepresentable
            enum Route {
                case detail(id: Int)
            }
            """,
            expandedSource: """
            enum Route {
                case detail(id: Int)
            }

            extension Route: RawRepresentable, StringRepresentableValue {
                internal var rawValue: String {
                    switch self {
                    case .detail(let value):
                        return "detail.\\(value.stringRepresentation)"
                    }
                }
                internal init?(rawValue: String) {
                    let components = rawValue.components(separatedBy: ".")
                    let firstComponent = components[0]
                    switch firstComponent {
                    case "detail":
                        let restComponents = components.suffix(from: 1)
                        let restString = restComponents.joined(separator: ".")
                        if !restComponents.isEmpty, let value = Int.read(fromStringRepresentation: restString) {
                            self = .detail(id: value)
                        } else {
                            return nil
                        }
                    default:
                        return nil
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    /// Only the first value was ever read, so the second went out and never came back. Refusing
    /// says so; the encoding has one tail and cannot carry two.
    func testCaseWithTwoAssociatedValues() {
        assertMacroExpansion(
            """
            @StringRepresentable
            enum Route {
                case settings(id: Int, name: String)
            }
            """,
            expandedSource: """
            enum Route {
                case settings(id: Int, name: String)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StringRepresentable writes one value after the dot, and `settings` carries more than one — there is no spelling that reads them all back. Wrap them in one value.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    func testCaseWithOptionalAssociatedValue() {
        assertMacroExpansion(
            """
            @StringRepresentable
            enum Route {
                case profile(name: String?)
            }
            """,
            expandedSource: """
            enum Route {
                case profile(name: String?)
            }

            extension Route: RawRepresentable, StringRepresentableValue {
                internal var rawValue: String {
                    switch self {
                    case .profile(let value):
                        if let value {
                            return "profile.\\(value.stringRepresentation)"
                        } else {
                            return "profile"
                        }
                    }
                }
                internal init?(rawValue: String) {
                    let components = rawValue.components(separatedBy: ".")
                    let firstComponent = components[0]
                    switch firstComponent {
                    case "profile":
                        let restComponents = components.suffix(from: 1)
                        let restString = restComponents.joined(separator: ".")
                        if restComponents.isEmpty {
                            self = .profile(name: nil)
                        } else if let value = String.read(fromStringRepresentation: restString) {
                            self = .profile(name: value)
                        } else {
                            return nil
                        }
                    default:
                        return nil
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testAppliedToNonEnum() {
        assertMacroExpansion(
            """
            @StringRepresentable
            struct NotAnEnum {}
            """,
            expandedSource: """
            struct NotAnEnum {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StringRepresentable can only be applied to enum", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }
}
