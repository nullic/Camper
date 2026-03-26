import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension StringRepresentableMacro: ExtensionMacro {
    public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                                 attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                                 providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
                                 conformingTo _: [SwiftSyntax.TypeSyntax],
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.ExtensionDeclSyntax]
    {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else { throw CamperMacrosError.stringIncorrectType }

        var members: [MemberBlockItemSyntax] = []
        try members.append(contentsOf: rawValueSyntax(with: enumDecl).map { MemberBlockItemSyntax(decl: $0) })
        try members.append(contentsOf: initWithRawValueSyntax(with: enumDecl).map { MemberBlockItemSyntax(decl: $0) })

        let header = SyntaxNodeString(stringLiteral: "extension \(type.trimmed): RawRepresentable")
        return try [
            ExtensionDeclSyntax(header, membersBuilder: { MemberBlockItemListSyntax(members) }),
        ]
    }
}
