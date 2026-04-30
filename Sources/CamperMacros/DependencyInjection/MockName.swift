import SwiftSyntax
import SwiftSyntaxMacros

/// Marker peer macro used by `@AutoMockable` to override the unique-name
/// prefix it generates for a method's mock members. The macro itself emits
/// no peers; `AutoMockable` reads the attribute argument off the function
/// declaration when building the prefix.
public enum MockName: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}
