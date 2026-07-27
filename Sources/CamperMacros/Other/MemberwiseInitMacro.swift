import Foundation
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

        let stored = structDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { variable in
                !variable.isStatic &&
                !variable.hasAccessorBlock &&
                !variable.identifier.isEmpty &&
                !variable.isInitializedConstant
            }
        guard !stored.isEmpty else { return [] }

        let access = structDecl.privacyModifier

        let params = stored.map { variable -> String in
            let defaultClause: String
            if let value = variable.initializerValue {
                defaultClause = " = \(value)"
            } else if variable.isOptional {
                defaultClause = " = nil"
            } else {
                defaultClause = ""
            }
            return "\(variable.identifier): \(variable.rawIdentifierType)\(defaultClause)"
        }.joined(separator: ", ")

        let initDecl = try InitializerDeclSyntax("\(raw: access) init(\(raw: params))") {
            for variable in stored {
                "self.\(raw: variable.identifier) = \(raw: variable.identifier)"
            }
        }

        return [DeclSyntax(initDecl)]
    }
}
