import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct Dependency {}

extension Dependency: PeerMacro {
    public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                                 providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax]
    {
        guard let variable = declaration.as(VariableDeclSyntax.self) else { throw CamperMacrosError.dependencyUnknowType }
        let typeString = variable.rawIdentifierType
        if typeString.isEmpty {
            throw CamperMacrosError.dependencyUnknowType
        }
        return []
    }
}

extension Dependency: AccessorMacro {
    public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                                 providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.AccessorDeclSyntax]
    {
        guard let variable = declaration.as(VariableDeclSyntax.self) else { throw CamperMacrosError.dependencyIncorrectType }
        if variable.isExplicitDependency {
            return [AccessorDeclSyntax(stringLiteral: "get { _explicitDependencies.\(variable.identifier) }")]
        }
        return [AccessorDeclSyntax(stringLiteral: "get { dependencies.\(variable.identifier) }")]
    }
}
