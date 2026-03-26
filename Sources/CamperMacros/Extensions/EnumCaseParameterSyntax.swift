import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EnumCaseParameterSyntax {
    var elementIdentifierType: String {
        if let typeSyntax = type.as(IdentifierTypeSyntax.self) {
            return typeSyntax.name.text
        } else if let typeSyntax = type.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self) {
            return typeSyntax.name.text
        } else if let typeSyntax = type.as(OptionalTypeSyntax.self) {
            if let typeSyntax = typeSyntax.wrappedType.as(IdentifierTypeSyntax.self) {
                return typeSyntax.name.text
            } else if let typeSyntax = typeSyntax.wrappedType.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self) {
                return typeSyntax.name.text
            }
        }

        return ""
    }

    var isOptional: Bool {
        return type.as(OptionalTypeSyntax.self) != nil
    }

    var isArray: Bool {
        return type.as(ArrayTypeSyntax.self) != nil
    }
}
