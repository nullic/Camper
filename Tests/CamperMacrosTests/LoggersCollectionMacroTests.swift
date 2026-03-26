import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CamperMacros

final class LoggersCollectionMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "LoggersCollection": LoggersCollectionMacro.self,
    ]

    func testLoggerWithExplicitSubsystem() {
        assertMacroExpansion(
            """
            @LoggersCollection("com.example.app")
            enum Loggers {
                enum Categories {
                    case network
                    case database
                }
            }
            """,
            expandedSource: """
            enum Loggers {
                enum Categories {
                    case network
                    case database
                }

                static let network = Logger(subsystem: "com.example.app", category: "Network")

                static let database = Logger(subsystem: "com.example.app", category: "Database")
            }
            """,
            macros: testMacros
        )
    }

    func testLoggerWithDefaultSubsystem() {
        assertMacroExpansion(
            """
            @LoggersCollection
            enum AppLoggers {
                enum Categories {
                    case ui
                }
            }
            """,
            expandedSource: """
            enum AppLoggers {
                enum Categories {
                    case ui
                }

                static let ui = Logger(subsystem: "App", category: "Ui")
            }
            """,
            macros: testMacros
        )
    }

    func testLoggerAppliedToNonEnum() {
        assertMacroExpansion(
            """
            @LoggersCollection("test")
            struct NotAnEnum {}
            """,
            expandedSource: """
            struct NotAnEnum {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@LoggersCollection can only be applied to enum", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }
}
