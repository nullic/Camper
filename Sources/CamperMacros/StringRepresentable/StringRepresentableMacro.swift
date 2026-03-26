import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum StringRepresentableMacro {
    static func rawValueSyntax(with enumDecl: EnumDeclSyntax) throws -> [DeclSyntax] {
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
                                        return "\(raw: element.name.text).\\(value.rawValue)"
                                    } else {
                                        return "\(raw: element.name.text)"
                                    }
                                """
                            )
                        } else {
                            SwitchCaseSyntax("case .\(raw: element.name.text)(let value): return \"\(raw: element.name.text).\\(value.rawValue)\"")
                        }
                    } else if element.parameterClause == nil {
                        SwitchCaseSyntax("case .\(raw: element.name.text): return \"\(raw: element.name.text)\"")
                    }
                }
            }
        }

        return [DeclSyntax(variable)]
    }

    static func initWithRawValueSyntax(with enumDecl: EnumDeclSyntax) throws -> [DeclSyntax] {
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
                                case \"\(raw: element.name.text)\":
                                    let restComponents = components.suffix(from: 1)
                                    let restString = restComponents.joined(separator: \".\")
                                    if restComponents.isEmpty {
                                        self = .\(raw: element.name.text)(nil)
                                    } else if let value = \(raw: parameter.elementIdentifierType)(rawValue: restString) {
                                        self = .\(raw: element.name.text)(value)
                                    } else {
                                        return nil
                                    }
                                """
                            )
                        } else {
                            SwitchCaseSyntax(
                                """
                                case \"\(raw: element.name.text)\":
                                    let restComponents = components.suffix(from: 1)
                                    let restString = restComponents.joined(separator: \".\")
                                    if !restComponents.isEmpty, let value = \(parameter.type)(rawValue: restString) {
                                        self = .\(raw: element.name.text)(value)
                                    } else {
                                        return nil
                                    }
                                """
                            )
                        }
                    } else {
                        SwitchCaseSyntax("case \"\(raw: element.name.text)\": self = .\(raw: element.name.text)")
                    }
                }
                SwitchCaseSyntax("default: return nil")
            }
        }

        return [DeclSyntax(initializer)]
    }
}
