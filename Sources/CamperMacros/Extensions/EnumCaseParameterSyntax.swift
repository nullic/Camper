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

    /// `id: ` for `case settings(id: Int)`, empty for a case whose value is unlabelled.
    ///
    /// Rebuilding the case without it compiled only for the unlabelled shape, which is the one
    /// the client happened to demonstrate.
    var argumentLabel: String {
        guard let name = firstName?.text, name != "_" else { return "" }
        return "\(name): "
    }

    var isOptional: Bool {
        return type.as(OptionalTypeSyntax.self) != nil
    }

    var isArray: Bool {
        return type.as(ArrayTypeSyntax.self) != nil
    }
}

extension EnumCaseElementSyntax {
    /// How this case spells itself in the string — its own name, or the snake_case the
    /// attribute asked for.
    func spelling(_ snakeCased: Bool) -> String {
        snakeCased ? name.text.snakeCased : name.text
    }
}
