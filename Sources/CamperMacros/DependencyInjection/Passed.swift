import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct Passed {}

extension Passed: PeerMacro {
    public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                                 providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax]
    {
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else { throw CamperMacrosError.passedIncorrectType }
        if varDecl.isOptional == false {
            throw CamperMacrosError.passedIncorrectType
        }
        return []
    }
}
