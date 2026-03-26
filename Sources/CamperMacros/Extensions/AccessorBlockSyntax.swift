import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension AccessorBlockSyntax {
    var isGetOnlyAccessorBlock: Bool {
        if accessors.as(CodeBlockItemListSyntax.self) != nil {
            return true
        } else if let list = accessors.as(AccessorDeclListSyntax.self) {
            for decl in list {
                if decl.accessorSpecifier.description != "get" {
                    return false
                }
            }
            return true
        } else {
            return false
        }
    }
}
