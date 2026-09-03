import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@SoftCodable` — see the declaration in `Camper/Macros/SoftCodable.swift`.
public enum SoftCodable {
    /// Instance stored properties (skip `static` and computed).
    static func storedProperties(of structDecl: StructDeclSyntax) -> [VariableDeclSyntax] {
        structDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { variable in
                !variable.modifiers.contains { $0.name.text == "static" }
                    && !variable.hasAccessorBlock
                    && !variable.identifier.isEmpty
            }
    }
}

// MARK: - Public memberwise init (the implicit one is `internal`; a public type
// needs a public one — e.g. to be a default argument elsewhere).

extension SoftCodable: MemberMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // A sum type has no properties to take — its cases are its initialisers — but it does
        // need a coder, and that coder has to be a member (see `SoftCodableEnumCoder`).
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return try SoftCodableEnumCoder.members(of: enumDecl)
        }
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw CamperMacrosError.softCodableIncorrectType
        }
        let stored = storedProperties(of: structDecl)
        guard !stored.isEmpty else { return [] }

        let access = structDecl.modifiers.contains { $0.name.text == "public" } ? "public " : ""
        let params = stored.map { variable -> String in
            let defaultClause: String
            if let value = variable.initializerValue {
                defaultClause = " = \(value)"
            } else if variable.isOptional {
                defaultClause = " = nil"
            } else {
                defaultClause = ""
            }
            return "\(variable.identifier): \(variable.rawIdentifierType)\(defaultClause)"
        }.joined(separator: ", ")
        let assignments = stored.map { "self.\($0.identifier) = \($0.identifier)" }
            .joined(separator: "\n        ")

        let initDecl: DeclSyntax = """
        \(raw: access)init(\(raw: params)) {
            \(raw: assignments)
        }
        """
        return [initDecl]
    }
}

// MARK: - Codable (snake_case keys, soft-fail decode)

extension SoftCodable: ExtensionMacro {
    public static func expansion(
        of _: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // The members are written by the member expansion; the extension only signs the
        // conformance.
        if declaration.as(EnumDeclSyntax.self) != nil {
            let source: DeclSyntax = "extension \(raw: type.trimmedDescription): Codable {}"
            guard let extensionDecl = source.as(ExtensionDeclSyntax.self) else { return [] }
            return [extensionDecl]
        }
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw CamperMacrosError.softCodableIncorrectType
        }

        // Instance stored properties only (skip `static` and computed).
        let stored = structDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { variable in
                !variable.modifiers.contains { $0.name.text == "static" }
                    && !variable.hasAccessorBlock
                    && !variable.identifier.isEmpty
            }

        let coded = stored.filter { !$0.attributes.contains(named: "SoftIgnore") }
        let ignored = stored.filter { $0.attributes.contains(named: "SoftIgnore") }

        let keyCases = coded.map { variable -> String in
            let name = variable.identifier
            let key = variable.softKey ?? name.snakeCased
            return key == name ? "case \(name)" : "case \(name) = \"\(key)\""
        }

        var decodeLines: [String] = coded.map { variable in
            let name = variable.identifier
            if variable.isOptional {
                return "self.\(name) = try container.decodeIfPresent(\(variable.unwrappedIdentifierType).self, forKey: .\(name))"
            } else if let defaultValue = variable.initializerValue,
                      !variable.attributes.contains(named: "SoftRequired")
            {
                return "self.\(name) = try container.decodeIfPresent(\(variable.rawIdentifierType).self, forKey: .\(name)) ?? \(defaultValue)"
            } else {
                return "self.\(name) = try container.decode(\(variable.rawIdentifierType).self, forKey: .\(name))"
            }
        }
        for variable in ignored {
            if let defaultValue = variable.initializerValue {
                decodeLines.append("self.\(variable.identifier) = \(defaultValue)")
            }
        }

        let encodeLines = coded.map { variable -> String in
            let name = variable.identifier
            let verb = variable.isOptional ? "encodeIfPresent" : "encode"
            return "try container.\(verb)(self.\(name), forKey: .\(name))"
        }

        let access = structDecl.modifiers.contains { $0.name.text == "public" } ? "public " : ""

        let extensionSource: DeclSyntax = """
        extension \(raw: type.trimmedDescription): Codable {
            enum CodingKeys: String, CodingKey {
                \(raw: keyCases.joined(separator: "\n        "))
            }

            \(raw: access)init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                \(raw: decodeLines.joined(separator: "\n        "))
            }

            \(raw: access)func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                \(raw: encodeLines.joined(separator: "\n        "))
            }
        }
        """

        guard let extensionDecl = extensionSource.as(ExtensionDeclSyntax.self) else { return [] }
        return [extensionDecl]
    }
}

/// `@SoftRequired` — a no-op marker read by `@SoftCodable`.
public enum SoftRequired: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

/// `@SoftKey` — a no-op marker read by `@SoftCodable`.
public enum SoftKey: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

/// `@SoftIgnore` — a no-op marker read by `@SoftCodable`.
public enum SoftIgnore: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}
