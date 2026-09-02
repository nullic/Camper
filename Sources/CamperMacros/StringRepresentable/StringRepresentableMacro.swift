import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum StringRepresentableMacro {
    /// How the attribute asked for the cases to be spelled. Absent argument ⇒ the case's own
    /// name, so an enum whose raw values are already stored keeps them.
    static func snakeCased(from node: AttributeSyntax) -> Bool {
        guard let argument = node.arguments?.as(LabeledExprListSyntax.self)?.first else { return false }
        return argument.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "snakeCase"
    }

    /// A case carrying two values has no spelling this encoding can read back — only the first
    /// was ever used, so the second was silently dropped on the way out and never came back in.
    /// Refusing to expand says so; guessing did not.
    static func checkSingleAssociatedValue(in enumDecl: EnumDeclSyntax) throws {
        for element in enumDecl.elements {
            let parameters = element.parameterClause?.parameters ?? []
            guard parameters.count > 1 else { continue }
            throw CamperMacrosError.stringMultipleAssociatedValues(caseName: element.name.text)
        }
    }

    static func rawValueSyntax(with enumDecl: EnumDeclSyntax, snakeCased: Bool) throws -> [DeclSyntax] {
        let cases = enumDecl.elements

        let variable = try VariableDeclSyntax("\(raw: enumDecl.privacyModifier) var rawValue: String") {
            try SwitchExprSyntax("switch self") {
                for element in cases {
                    if let parameter = element.parameterClause?.parameters.first {
                        if parameter.isOptional {
                            SwitchCaseSyntax(
                                """
                                case .\(raw: element.name.text)(let value):
                                    if let value {
                                        return "\(raw: element.spelling(snakeCased)).\\(value.stringRepresentation)"
                                    } else {
                                        return "\(raw: element.spelling(snakeCased))"
                                    }
                                """
                            )
                        } else {
                            SwitchCaseSyntax("case .\(raw: element.name.text)(let value): return \"\(raw: element.spelling(snakeCased)).\\(value.stringRepresentation)\"")
                        }
                    } else {
                        SwitchCaseSyntax("case .\(raw: element.name.text): return \"\(raw: element.spelling(snakeCased))\"")
                    }
                }
            }
        }

        return [DeclSyntax(variable)]
    }

    static func initWithRawValueSyntax(with enumDecl: EnumDeclSyntax, snakeCased: Bool) throws -> [DeclSyntax] {
        let cases = enumDecl.elements

        let initializer = try InitializerDeclSyntax("\(raw: enumDecl.privacyModifier) init?(rawValue: String)") {
            "let components = rawValue.components(separatedBy: \".\")"
            "let firstComponent = components[0]"

            try SwitchExprSyntax("switch firstComponent") {
                for element in cases {
                    // EnumCaseParameterSyntax
                    if let parameter = element.parameterClause?.parameters.first {
                        if parameter.isOptional {
                            SwitchCaseSyntax(
                                """
                                case \"\(raw: element.spelling(snakeCased))\":
                                    let restComponents = components.suffix(from: 1)
                                    let restString = restComponents.joined(separator: \".\")
                                    if restComponents.isEmpty {
                                        self = .\(raw: element.name.text)(\(raw: parameter.argumentLabel)nil)
                                    } else if let value = \(raw: parameter.elementIdentifierType).read(fromStringRepresentation: restString) {
                                        self = .\(raw: element.name.text)(\(raw: parameter.argumentLabel)value)
                                    } else {
                                        return nil
                                    }
                                """
                            )
                        } else {
                            SwitchCaseSyntax(
                                """
                                case \"\(raw: element.spelling(snakeCased))\":
                                    let restComponents = components.suffix(from: 1)
                                    let restString = restComponents.joined(separator: \".\")
                                    if !restComponents.isEmpty, let value = \(raw: parameter.elementIdentifierType).read(fromStringRepresentation: restString) {
                                        self = .\(raw: element.name.text)(\(raw: parameter.argumentLabel)value)
                                    } else {
                                        return nil
                                    }
                                """
                            )
                        }
                    } else {
                        SwitchCaseSyntax("case \"\(raw: element.spelling(snakeCased))\": self = .\(raw: element.name.text)")
                    }
                }
                SwitchCaseSyntax("default: return nil")
            }
        }

        return [DeclSyntax(initializer)]
    }
}
