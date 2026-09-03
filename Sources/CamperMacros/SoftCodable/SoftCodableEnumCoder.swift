import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Codable for a sum type (case name as the key, the value written inline)

/// What `@SoftCodable` generates for an `enum`. A struct describes its properties, so the
/// macro had nothing to say about a sum type and refused to expand — and the synthesised
/// `Codable` a compiler writes instead spells the payload `_0`, which is unreadable in a
/// document people author by hand.
///
/// The spelling is the case's snake_case name as the only key, and the value directly under
/// it: `establish: {id: fact_log}`, `spend: {resource: doom, amount: 1}`, and a case with no
/// value as a bare string, `finish`. `@StringRepresentable` stays the answer where the whole
/// case fits in one string; this is the answer where a case carries a record.
enum SoftCodableEnumCoder {
    /// One case, read off the declaration.
    private struct Element {
        var name: String
        var key: String
        var parameters: [EnumCaseParameterSyntax]

        var keyCase: String {
            key == name ? "case \(name)" : "case \(name) = \"\(key)\""
        }

        /// `SpendKeys` — the keys the values of a multi-value case are written under.
        var nestedKeysName: String {
            "\(name.prefix(1).uppercased())\(name.dropFirst())Keys"
        }
    }

    /// The coder is generated as **members** of the enum, not in an extension: an extension is
    /// not lexically inside the enclosing type, so a payload type nested beside the enum
    /// (`case establish(Fact)`) would not resolve there. As members it sees whatever the enum
    /// sees.
    static func members(of enumDecl: EnumDeclSyntax) throws -> [DeclSyntax] {
        let elements = try read(enumDecl)
        guard !elements.isEmpty else { return [] }

        let access = enumDecl.isPublicOrOpen ? "public " : ""
        let keys: DeclSyntax = """
        enum CodingKeys: String, CodingKey {
            \(raw: elements.map(\.keyCase).joined(separator: "\n    "))
        }
        """
        let decoder: DeclSyntax = """
        \(raw: access)init(from decoder: any Decoder) throws {
            \(raw: decodeBody(elements).joined(separator: "\n    "))
        }
        """
        let encoder: DeclSyntax = """
        \(raw: access)func encode(to encoder: any Encoder) throws {
            \(raw: encodeBody(elements).joined(separator: "\n    "))
        }
        """
        return [keys, decoder, encoder]
    }

    private static func read(_ enumDecl: EnumDeclSyntax) throws -> [Element] {
        try enumDecl.elements.map { element in
            let parameters = Array(element.parameterClause?.parameters ?? [])
            // Two values need two keys, and an unlabelled value has no name to write it
            // under — `_0` again. Refusing says so; guessing a name would not.
            if parameters.count > 1 {
                for parameter in parameters where parameter.argumentLabel.isEmpty {
                    throw CamperMacrosError.softCodableUnlabelledValues(caseName: element.name.text)
                }
            }
            return Element(name: element.name.text, key: element.name.text.snakeCased, parameters: parameters)
        }
    }

    private static func nestedKeyDecls(_ elements: [Element]) -> [String] {
        elements.filter { $0.parameters.count > 1 }.map { element in
            let cases = element.parameters.map { parameter -> String in
                let label = parameter.label
                let key = label.snakeCased
                return key == label ? "case \(label)" : "case \(label) = \"\(key)\""
            }
            return """
            enum \(element.nestedKeysName): String, CodingKey {
                    \(cases.joined(separator: "\n            "))
                }
            """
        }
    }

    private static func decodeBody(_ elements: [Element]) -> [String] {
        var lines = nestedKeyDecls(elements)
        let plain = elements.filter(\.parameters.isEmpty)
        if !plain.isEmpty {
            let arms = plain.map { "case \"\($0.key)\": self = .\($0.name); return" }
            lines.append("""
            if let name = try? decoder.singleValueContainer().decode(String.self) {
                    switch name {
                    \(arms.joined(separator: "\n            "))
                    default:
                        throw DecodingError.dataCorrupted(DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "`\\(name)` is not a case of \\(Self.self)"
                        ))
                    }
                }
            """)
        }
        lines.append("let container = try decoder.container(keyedBy: CodingKeys.self)")
        lines.append("""
        guard let key = container.allKeys.first else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "no case of \\(Self.self) is named here"
                ))
            }
        """)
        let arms = elements.map { element -> String in
            switch element.parameters.count {
            case 0:
                return "case .\(element.name): self = .\(element.name)"
            case 1:
                let parameter = element.parameters[0]
                let value = "try container.decode(\(parameter.type.trimmedDescription).self, forKey: .\(element.name))"
                return "case .\(element.name): self = .\(element.name)(\(parameter.argumentLabel)\(value))"
            default:
                let reads = element.parameters.map { parameter in
                    "\(parameter.label): try nested.decode(\(parameter.type.trimmedDescription).self, forKey: .\(parameter.label))"
                }
                return """
                case .\(element.name):
                    let nested = try container.nestedContainer(keyedBy: \(element.nestedKeysName).self, forKey: .\(element.name))
                    self = .\(element.name)(\(reads.joined(separator: ", ")))
                """
            }
        }
        lines.append("""
        switch key {
            \(arms.joined(separator: "\n        "))
            }
        """)
        return lines
    }

    private static func encodeBody(_ elements: [Element]) -> [String] {
        var lines = nestedKeyDecls(elements)
        let arms = elements.map { element -> String in
            switch element.parameters.count {
            case 0:
                return """
                case .\(element.name):
                    var container = encoder.singleValueContainer()
                    try container.encode("\(element.key)")
                """
            case 1:
                return """
                case .\(element.name)(let value):
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(value, forKey: .\(element.name))
                """
            default:
                let bindings = element.parameters.map { "let \($0.label)" }.joined(separator: ", ")
                let writes = element.parameters.map { "try nested.encode(\($0.label), forKey: .\($0.label))" }
                return """
                case .\(element.name)(\(bindings)):
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    var nested = container.nestedContainer(keyedBy: \(element.nestedKeysName).self, forKey: .\(element.name))
                    \(writes.joined(separator: "\n            "))
                """
            }
        }
        lines.append("""
        switch self {
            \(arms.joined(separator: "\n        "))
            }
        """)
        return lines
    }
}

extension EnumCaseParameterSyntax {
    /// The value's own name, without the trailing `: ` that rebuilding a case needs.
    var label: String {
        guard let name = firstName?.text, name != "_" else { return "" }
        return name
    }
}
