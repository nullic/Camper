import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension ProtocolDeclSyntax {
    var allVariables: [VariableDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
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

    var parentInjectionProtocol: String? {
        guard let inheritanceClause else { return nil }
        for inherited in inheritanceClause.inheritedTypes {
            let name = inherited.type.trimmedDescription
            if name.hasSuffix("Injection"), name != "AnyObject", !name.contains("Sendable"), !name.contains(".") {
                return name
            }
        }
        return nil
    }
}
