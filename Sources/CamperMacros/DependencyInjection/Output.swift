import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct Output {}

extension Output: PeerMacro {
    public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                                 providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax]
    {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else { throw CamperMacrosError.outputIncorrectType }
        let typeString = variableDecl.rawIdentifierType
        if typeString.isEmpty {
            throw CamperMacrosError.outputUnknowType
        }

        return []
    }
}
