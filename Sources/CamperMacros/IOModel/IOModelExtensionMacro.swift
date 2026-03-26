import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension IOModel: ExtensionMacro {
    public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                                 attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                                 providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
                                 conformingTo _: [SwiftSyntax.TypeSyntax],
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.ExtensionDeclSyntax]
    {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else { throw CamperMacrosError.ioModelIncorrectType }
        guard classDecl.attributes.contains(named: "Model") else { return [] }

        var members: [MemberBlockItemSyntax] = []

        var conformanseString = ""
        let uniqueDels = uniqueConformanceSyntax(with: classDecl)
        if !uniqueDels.isEmpty {
            conformanseString = ": UniqueFindable"
            members.append(contentsOf: uniqueDels.map { MemberBlockItemSyntax(decl: $0) })
        }

        try members.append(contentsOf: insertFuncsSyntax(with: classDecl).map { MemberBlockItemSyntax(decl: $0) })

        let header = SyntaxNodeString(stringLiteral: "extension \(type.trimmed)\(conformanseString)")
        return try [
            ExtensionDeclSyntax(header, membersBuilder: { MemberBlockItemListSyntax(members) }),
        ]
    }
}
