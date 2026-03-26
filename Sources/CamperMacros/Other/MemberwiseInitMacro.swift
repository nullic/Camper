import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum MemberwiseInit: MemberMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw CamperMacrosError.memberwiseInitIncorrectType
        }

        let properties = storedProperties(from: structDecl)
        guard !properties.isEmpty else { return [] }

        let access = structDecl.accessLevelModifier.map { "\($0) " } ?? ""

        let params = properties.map { prop in
            let defaultValue = prop.isOptional ? " = nil" : ""
            return "\(prop.name): \(prop.typeName)\(defaultValue)"
        }.joined(separator: ",\n        ")

        let assignments = properties.map { "self.\($0.name) = \($0.name)" }
            .joined(separator: "\n        ")

        let initDecl: DeclSyntax = """
            \(raw: access)init(
                \(raw: params)
            ) {
                \(raw: assignments)
            }
            """

        return [initDecl]
    }
}

// MARK: - Helpers

private struct StoredProperty {
    let name: String
    let typeName: String
    var isOptional: Bool { typeName.hasSuffix("?") }
}

private func storedProperties(from structDecl: StructDeclSyntax) -> [StoredProperty] {
    structDecl.memberBlock.members.compactMap { member -> StoredProperty? in
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              binding.accessorBlock == nil,
              binding.initializer == nil,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation
        else { return nil }
        return StoredProperty(
            name: pattern.identifier.trimmedDescription,
            typeName: typeAnnotation.type.trimmedDescription
        )
    }
}

private extension StructDeclSyntax {
    var accessLevelModifier: String? {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public): return "public"
            case .keyword(.package): return "package"
            case .keyword(.internal): return "internal"
            case .keyword(.private): return "private"
            case .keyword(.fileprivate): return "fileprivate"
            default: continue
            }
        }
        return nil
    }
}
