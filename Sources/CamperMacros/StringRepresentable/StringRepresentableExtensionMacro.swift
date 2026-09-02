import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension StringRepresentableMacro: ExtensionMacro {
    public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                                 attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                                 providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
                                 conformingTo _: [SwiftSyntax.TypeSyntax],
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.ExtensionDeclSyntax]
    {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else { throw CamperMacrosError.stringIncorrectType }

        try checkSingleAssociatedValue(in: enumDecl)

        let snakeCased = snakeCased(from: node)
        var members: [MemberBlockItemSyntax] = []
        try members.append(contentsOf: rawValueSyntax(with: enumDecl, snakeCased: snakeCased).map { MemberBlockItemSyntax(decl: $0) })
        try members.append(contentsOf: initWithRawValueSyntax(with: enumDecl, snakeCased: snakeCased).map { MemberBlockItemSyntax(decl: $0) })

        let header = SyntaxNodeString(stringLiteral: "extension \(type.trimmed): RawRepresentable, StringRepresentableValue")
        return try [
            ExtensionDeclSyntax(header, membersBuilder: { MemberBlockItemListSyntax(members) }),
        ]
    }
}
