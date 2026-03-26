import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CamperMacros

final class LocalizedMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "localized": LocalizedMacro.self,
    ]

    func testLocalizedDefaultBundle() {
        assertMacroExpansion(
            """
            let text = #localized("hello_world")
            """,
            expandedSource: """
            let text = LocalizedStringResource("hello_world", bundle: .main)
            """,
            macros: testMacros
        )
    }

    func testLocalizedWithMemberBundle() {
        assertMacroExpansion(
            """
            let text = #localized("hello_world", .module)
            """,
            expandedSource: """
            let text = LocalizedStringResource("hello_world", bundle: .atURL(Bundle.module.bundleURL))
            """,
            macros: testMacros
        )
    }

    func testLocalizedWithVariableBundle() {
        assertMacroExpansion(
            """
            let text = #localized("hello_world", myBundle)
            """,
            expandedSource: """
            let text = LocalizedStringResource("hello_world", bundle: .atURL(myBundle.bundleURL))
            """,
            macros: testMacros
        )
    }
}
