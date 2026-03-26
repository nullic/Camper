import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LocalizedMacro: ExpressionMacro {
    public static func expansion(of node: some SwiftSyntax.FreestandingMacroExpansionSyntax,
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> SwiftSyntax.ExprSyntax
    {
        guard let string = node.arguments.first else { fatalError("macro needs an value") }

        let bundle: String
        if node.arguments.count > 1, let argument = node.arguments.last?.description {
            if argument.hasPrefix(".") {
                bundle = ".atURL(Bundle\(argument).bundleURL)"
            } else {
                bundle = ".atURL(\(argument).bundleURL)"
            }
        } else {
            bundle = ".main"
        }

        return "LocalizedStringResource(\(raw: string.expression.description), bundle: \(raw: bundle))"
    }
}
