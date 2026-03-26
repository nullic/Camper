import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension LabeledExprListSyntax {
    func first(label: String) -> LabeledExprSyntax? {
        return first { labeledExpr in
            labeledExpr.label?.text == label
        }
    }

    func has(label: String) -> Bool {
        contains { syntax in
            if let syntax = syntax.expression.as(MemberAccessExprSyntax.self) {
                return syntax.declName.baseName.text == label
            }
            return false
        }
    }

    func boolValue(label: String) -> Bool? {
        guard let expr = first(where: { $0.label?.text == label })?.expression else { return nil }
        return expr.as(BooleanLiteralExprSyntax.self)?.literal.tokenKind == .keyword(.true)
    }
}
