import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension SyntaxChildren {
    func first<T>(type _: T.Type) -> T? where T: SyntaxProtocol {
        first(where: { $0.as(T.self) != nil })?.as(T.self)
    }
}
