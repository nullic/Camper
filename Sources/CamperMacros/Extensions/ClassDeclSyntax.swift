import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension ClassDeclSyntax {
    var allFunctions: [FunctionDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }
    }

    /// The properties that find a record: every `@IOKey` one; else the first set of SwiftData's
    /// `#Unique`; else the `@Attribute(.unique)` one. Two or more make a compound key.
    var keyVariables: [VariableDeclSyntax] {
        let marked = allVariables.filter(\.isKey)
        if !marked.isEmpty { return marked }
        let named = uniqueMacroKeyNames
        let listed = named.compactMap { name in allVariables.first { $0.identifier == name } }
        if !listed.isEmpty, listed.count == named.count { return listed }
        return allVariables.first(where: { $0.isUnique }).map { [$0] } ?? []
    }

    /// `[a, b]` of `#Unique<Item>([\.a, \.b], [\.c])`: its first set.
    var uniqueMacroKeyNames: [String] {
        for member in memberBlock.members {
            guard let expansion = member.decl.as(MacroExpansionDeclSyntax.self),
                  expansion.macroName.text == "Unique",
                  let set = expansion.arguments.first?.expression.as(ArrayExprSyntax.self)
            else { continue }
            return set.elements.compactMap {
                $0.expression.as(KeyPathExprSyntax.self)?.components.first?.component.as(KeyPathPropertyComponentSyntax.self)?.declName.baseName.text
            }
        }
        return []
    }

    func isKey(_ variable: VariableDeclSyntax) -> Bool {
        keyVariables.contains { $0.identifier == variable.identifier }
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
        inputVariables.filter { !isKey($0) }
    }

    var isOpen: Bool { modifiers.contains(where: { $0.name.tokenKind == .keyword(.open) }) }
    var isPublic: Bool { modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) }) }
    var isPackage: Bool { modifiers.contains(where: { $0.name.tokenKind == .keyword(.package) }) }
    var isPublicOrOpen: Bool { modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.open) }) }

    var isFileprivate: Bool { modifiers.contains(where: { $0.name.tokenKind == .keyword(.fileprivate) }) }
    var isPrivate: Bool { modifiers.contains(where: { $0.name.tokenKind == .keyword(.private) }) }
    var isPrivateOrFileprivate: Bool { modifiers.contains(where: { $0.name.tokenKind == .keyword(.private) || $0.name.tokenKind == .keyword(.fileprivate) }) }

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
