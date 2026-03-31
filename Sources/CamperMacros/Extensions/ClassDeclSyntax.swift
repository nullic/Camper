import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension ClassDeclSyntax {
    var allFunctions: [FunctionDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }
    }

    var uniqueVariable: VariableDeclSyntax? {
        allVariables.first(where: { $0.isUnique })
    }

    var allVariables: [VariableDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
    }

    var inputVariables: [VariableDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }.filter {
            !$0.isVirtual && !$0.isInitializedConstant && !$0.hasGetOnlyAccessorBlock && !$0.isTransient
        }
    }

    var computedVariables: [VariableDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }.filter {
            !$0.isVirtual && !$0.isTransient && $0.hasGetOnlyAccessorBlock
        }
    }

    var inputWritableVariables: [VariableDeclSyntax] {
        inputVariables.filter { !$0.isUnique }
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
