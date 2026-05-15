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
            // `xcstrings` auto-extraction (`SWIFT_EMIT_LOC_STRINGS`)
            // walks macro expansions and treats two specific
            // `LocalizedStringResource.BundleDescription` shapes as
            // first-class:
            //   • `bundle: .main`
            //   • `bundle: .atURL(Bundle.<module>.bundleURL)`
            // The earlier `.atURL(Bundle.main.bundleURL)` form was
            // opaque — every key ended up flagged as `stale` because
            // the extractor couldn't match it to a known bundle.
            // Hand `.main` through as the literal case; route every
            // other accessor (.module, .myCustomBundle, …) through
            // the URL form so module-scoped catalogues still resolve.
            let trimmed = argument.trimmingCharacters(in: .whitespaces)
            if trimmed == ".main" {
                bundle = ".main"
            } else if trimmed.hasPrefix(".") {
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
