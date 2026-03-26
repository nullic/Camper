import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension AttributeListSyntax {
    func contains(named: String) -> Bool {
        return first(named: named) != nil
    }

    func first(named: String) -> AttributeSyntax? {
        for item in self {
            guard let attr = item.as(AttributeSyntax.self) else { continue }
            guard let name = attr.attributeName.as(IdentifierTypeSyntax.self)?.name else { continue }

            if name.text == named {
                return attr
            }
        }

        return nil
    }

    var outputArguments: LabeledExprListSyntax? {
        first(named: "Output")?.arguments?.as(LabeledExprListSyntax.self)
    }

    var dependencyArguments: LabeledExprListSyntax? {
        first(named: "Dependency")?.arguments?.as(LabeledExprListSyntax.self)
    }

    var injectionArguments: LabeledExprListSyntax? {
        first(named: "Injection")?.arguments?.as(LabeledExprListSyntax.self)
    }

    var injectorArguments: LabeledExprListSyntax? {
        first(named: "Injector")?.arguments?.as(LabeledExprListSyntax.self)
    }

    var injectorType: String? {
        return injectionArguments?.first(label: "injectorType").map { syntax in
            if let decl = syntax.expression.as(DeclReferenceExprSyntax.self) {
                return decl.baseName.text
            } else if let decl = syntax.expression.as(MemberAccessExprSyntax.self)?.base?.as(DeclReferenceExprSyntax.self) {
                return decl.baseName.text
            } else {
                return syntax.expression.description
            }
        }
    }
}
