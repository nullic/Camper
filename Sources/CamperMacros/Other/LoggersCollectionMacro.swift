import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LoggersCollectionMacro: MemberMacro {
    public static func expansion(of node: AttributeSyntax,
                                 providingMembersOf declaration: some DeclGroupSyntax,
                                 conformingTo _: [TypeSyntax],
                                 in _: some MacroExpansionContext) throws -> [DeclSyntax]
    {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw CamperMacrosError.loggersNotCorrectType
        }

        let subsystem: String
        if let firstArg = node.arguments?.as(LabeledExprListSyntax.self)?.first,
           let value = firstArg.expression.as(StringLiteralExprSyntax.self)?.segments.trimmedDescription
        {
            subsystem = value
        } else {
            subsystem = enumDecl.name.text
                .replacingOccurrences(of: "LoggersCollection", with: "")
                .replacingOccurrences(of: "Loggers", with: "")
        }

        let innerEnums = enumDecl.memberBlock.members.compactMap { $0.decl.as(EnumDeclSyntax.self) }
        guard let categoriesEnum = innerEnums.first(where: { $0.name.text == "Categories" }) else {
            throw CamperMacrosError.loggersCategoriesNotFound
        }

        let cases = categoriesEnum.memberBlock.members.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }.compactMap { $0.elements.compactMap { $0.name.text } }.flatMap { $0 }

        return cases.map {
            let stringLiteral = "static let \($0) = Logger(subsystem: \"\(subsystem)\", category: \"\($0.capitalized)\")"
            return DeclSyntax(stringLiteral: stringLiteral)
        }
    }
}
