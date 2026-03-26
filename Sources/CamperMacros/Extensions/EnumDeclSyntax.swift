import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension EnumDeclSyntax {
    var cases: [EnumCaseDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
    }

    var elements: [EnumCaseElementSyntax] {
        cases.flatMap { $0.elements }
    }

    var isOpen: Bool { modifiers.contains(where: { $0.name.text == "open" }) }
    var isPublic: Bool { modifiers.contains(where: { $0.name.text == "public" }) }
    var isPackage: Bool { modifiers.contains(where: { $0.name.text == "package" }) }
    var isPublicOrOpen: Bool { modifiers.contains(where: { $0.name.text == "public" || $0.name.text == "open" }) }

    var isFileprivate: Bool { modifiers.contains(where: { $0.name.text == "fileprivate" }) }
    var isPrivate: Bool { modifiers.contains(where: { $0.name.text == "private" }) }
    var isPrivateOrFileprivate: Bool { modifiers.contains(where: { $0.name.text == "private" || $0.name.text == "fileprivate" }) }

    var privacyModifier: String {
        if isPublicOrOpen {
            return "public"
        } else if isPackage {
            return "package"
        } else if isPrivateOrFileprivate {
            return "fileprivate"
        } else {
            return "internal"
        }
    }
}
