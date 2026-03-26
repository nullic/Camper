import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension IOModel: MemberMacro {
    public static func expansion(of _: AttributeSyntax,
                                 providingMembersOf declaration: some DeclGroupSyntax,
                                 conformingTo _: [TypeSyntax],
                                 in _: some MacroExpansionContext) throws -> [DeclSyntax]
    {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else { throw CamperMacrosError.ioModelIncorrectType }

        var result: [DeclSyntax] = []
        try result.append(contentsOf: attributeEnumsSyntax(with: classDecl))
        try result.append(inputProtocolSyntax(with: classDecl))
        try result.append(initWithInputSyntax(with: classDecl))
        try result.append(updateWithInputSyntax(with: classDecl))

        try result.append(snapshotDeclSyntax(with: classDecl))
        try result.append(createSnapshotSyntax(with: classDecl))
        try result.append(contentsOf: createBackgroundChangesMonitorSyntax(with: classDecl))

        return result
    }
}
