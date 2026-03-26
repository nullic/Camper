import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension FunctionDeclSyntax {
    var isSetup: Bool {
        name.trimmed.text == "setup" && signature.parameterClause.parameters.isEmpty
    }
}
