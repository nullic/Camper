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

            extension Route: RawRepresentable {
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

            extension Route: RawRepresentable {
                internal var rawValue: String {
                    switch self {
                    case .detail(let value):
                        return "detail.\\(value.rawValue)"
                    }
                }
                internal init?(rawValue: String) {
                    let components = rawValue.components(separatedBy: ".")
                    let firstComponent = components[0]
                    switch firstComponent {
                    case "detail":
                        let restComponents = components.suffix(from: 1)
                        let restString = restComponents.joined(separator: ".")
                        if !restComponents.isEmpty, let value = Int(rawValue: restString) {
                            self = .detail(value)
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

            extension Route: RawRepresentable {
                internal var rawValue: String {
                    switch self {
                    case .profile(let value):
                        if let value {
                            return "profile.\\(value.rawValue)"
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
                            self = .profile(nil)
                        } else if let value = String(rawValue: restString) {
                            self = .profile(value)
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
