import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension VariableDeclSyntax {
    var identifier: String {
        for binding in bindings {
            guard let pattern = binding.children(viewMode: .all).first(type: IdentifierPatternSyntax.self) else { continue }
            return pattern.identifier.text
        }
        return ""
    }

    var rawIdentifierType: String {
        for binding in bindings {
            guard let pattern = binding.children(viewMode: .all).first(type: TypeAnnotationSyntax.self) else { continue }
            return pattern.type.trimmedDescription
        }
        return ""
    }

    var unwrappedIdentifierType: String {
        rawIdentifierType.hasSuffix("?") ? String(rawIdentifierType.prefix(rawIdentifierType.count - 1)) : rawIdentifierType
    }

    var elementIdentifierType: String {
        for binding in bindings {
            guard let pattern = binding.children(viewMode: .all).first(type: TypeAnnotationSyntax.self) else { continue }
            if let typeSyntax = pattern.type.as(IdentifierTypeSyntax.self) {
                return typeSyntax.name.text
            } else if let typeSyntax = pattern.type.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self) {
                return typeSyntax.name.text
            } else if let typeSyntax = pattern.type.as(OptionalTypeSyntax.self) {
                if let typeSyntax = typeSyntax.wrappedType.as(IdentifierTypeSyntax.self) {
                    return typeSyntax.name.text
                } else if let typeSyntax = typeSyntax.wrappedType.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self) {
                    return typeSyntax.name.text
                }
            } else if let typeSyntax = pattern.type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                if let typeSyntax = typeSyntax.wrappedType.as(IdentifierTypeSyntax.self) {
                    return typeSyntax.name.text
                } else if let typeSyntax = typeSyntax.wrappedType.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self) {
                    return typeSyntax.name.text
                }
            }
        }

        return ""
    }

    var inputModelIdentifierType: String {
        let type = elementIdentifierType.asInputModel
        return isArray ? "[\(type)]" : type
    }

    var linkIdentifierType: String {
        let type = elementIdentifierType + ".UniqueID"
        return isArray ? "[\(type)]" : type
    }

    func inputProtocolIdentifierType(className: String) -> String {
        (isRelationship || isIgnorable) ? "\(className).\(identifier.asInputEnum)" : rawIdentifierType
    }

    var isUnique: Bool {
        guard let list = attributes.first(named: "Attribute")?.arguments?.as(LabeledExprListSyntax.self) else { return false }
        return list.contains { syntax in
            syntax.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "unique"
        }
    }

    var isConstant: Bool {
        bindingSpecifier.text == "let"
    }

    var isVariable: Bool {
        bindingSpecifier.text == "var"
    }

    var isInitializedConstant: Bool {
        isConstant && bindings.first?.initializer != nil
    }

    var isInitableConstant: Bool {
        isConstant && bindings.first?.initializer == nil
    }

    var hasAccessorBlock: Bool {
        bindings.first?.accessorBlock != nil
    }

    var hasGetOnlyAccessorBlock: Bool {
        bindings.first?.accessorBlock?.isGetOnlyAccessorBlock ?? false
    }

    var isOptional: Bool {
        for binding in bindings {
            guard let pattern = binding.children(viewMode: .all).first(type: TypeAnnotationSyntax.self) else { continue }
            return pattern.type.as(OptionalTypeSyntax.self) != nil || pattern.type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) != nil
        }
        return false
    }

    var isArray: Bool {
        for binding in bindings {
            guard let pattern = binding.children(viewMode: .all).first(type: TypeAnnotationSyntax.self) else { continue }
            if pattern.type.as(ArrayTypeSyntax.self) != nil { return true }
            if pattern.type.as(OptionalTypeSyntax.self)?.wrappedType.as(ArrayTypeSyntax.self) != nil { return true }
        }
        return false
    }

    var isTransient: Bool { attributes.contains(named: "Transient") }
    var isRelationship: Bool { attributes.contains(named: "Relationship") }
    var isVirtual: Bool { attributes.contains(named: "Virtual") }
    var isNonLinkable: Bool { attributes.contains(named: "NonLinkable") }
    var isDependency: Bool { attributes.contains(named: "Dependency") }
    var isExplicitDependency: Bool { attributes.dependencyArguments?.has(label: "explicit") ?? false }
    var isOutput: Bool { attributes.contains(named: "Output") }
    var isInternalOutput: Bool { attributes.outputArguments?.has(label: "internal") ?? false }
    var isSubscriptOutput: Bool { attributes.outputArguments?.has(label: "subscript") ?? false }
    var isSubscriptDependency: Bool { attributes.dependencyArguments?.has(label: "subscript") ?? false }
    var isIgnorable: Bool { attributes.contains(named: "Ignorable") }
    var isPassed: Bool { attributes.contains(named: "Passed") }

    var hasSetter: Bool {
        guard let accessorBlock = bindings.first?.accessorBlock,
              let list = accessorBlock.accessors.as(AccessorDeclListSyntax.self)
        else { return false }
        return list.contains { $0.accessorSpecifier.text == "set" }
    }

    var originPath: String? {
        guard let attr = attributes.first(named: "Origin"),
              let args = attr.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = args.first?.expression.as(StringLiteralExprSyntax.self)
        else { return nil }
        return firstArg.segments.trimmedDescription
    }

    var initializerValue: String? {
        for binding in bindings {
            guard let pattern = binding.children(viewMode: .all).first(type: InitializerClauseSyntax.self) else { continue }
            return pattern.value.description
        }
        return nil
    }

    var defaultValue: String? {
        if isRelationship || isIgnorable {
            return ".ignore"
        }

        return initializerValue
    }

    var isPublic: Bool { modifiers.contains(where: { $0.name.text == "public" }) }
    var isPackage: Bool { modifiers.contains(where: { $0.name.text == "package" }) }
    var isFileprivate: Bool { modifiers.contains(where: { $0.name.text == "fileprivate" }) }
    var isPrivate: Bool { modifiers.contains(where: { $0.name.text == "private" && $0.detail == nil }) }
    var isPrivateOrFileprivate: Bool { modifiers.contains(where: { ($0.name.text == "private" || $0.name.text == "fileprivate") && $0.detail == nil }) }

    var readPrivacyModifier: String {
        if isPublic {
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
