import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum AutoMockable: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw CamperMacrosError.autoMockableIncorrectType
        }

        let protocolName = protocolDecl.name.trimmedDescription
        let mockName = "\(protocolName)Mock"
        let access = protocolDecl.accessLevelKeyword

        var sections: [String] = []

        for member in protocolDecl.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                sections.append(generatePropertyMock(varDecl, access: access))
            } else if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                sections.append(generateMethodMock(funcDecl, access: access))
            }
        }

        let body = sections.joined(separator: "\n\n")

        let classDecl = """
        \(access)class \(mockName): \(protocolName), @unchecked Sendable {

            \(access)init() {}

        \(body)
        }
        """

        return [DeclSyntax(stringLiteral: classDecl)]
    }

    // MARK: - Property Mock Generation

    private static func generatePropertyMock(_ varDecl: VariableDeclSyntax, access: String) -> String {
        guard let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation
        else { return "" }

        let name = pattern.identifier.trimmedDescription
        let typeName = typeAnnotation.type.trimmedDescription

        if let accessorBlock = binding.accessorBlock,
           case .accessors(let accessors) = accessorBlock.accessors,
           accessors.contains(where: { $0.effectSpecifiers?.asyncSpecifier != nil })
        {
            return generateAsyncPropertyMock(name: name, typeName: typeName, access: access)
        }

        if typeName.hasSuffix("?") {
            return "    \(access)var \(name): \(typeName)"
        }

        let capitalizedName = name.prefix(1).uppercased() + name.dropFirst()
        return """
            \(access)var \(name): \(typeName) {
                get { return underlying\(capitalizedName) }
                set(value) { underlying\(capitalizedName) = value }
            }
            \(access)var underlying\(capitalizedName): \(makeImplicitlyUnwrapped(typeName))
        """
    }

    private static func generateAsyncPropertyMock(name: String, typeName: String, access: String) -> String {
        """
            \(access)var \(name)CallsCount = 0
            \(access)var \(name)Called: Bool {
                return \(name)CallsCount > 0
            }

            \(access)var \(name): \(typeName) {
                get async {
                    \(name)CallsCount += 1
                    if let \(name)Closure = \(name)Closure {
                        return await \(name)Closure()
                    } else {
                        return underlying\(name.prefix(1).uppercased() + name.dropFirst())
                    }
                }
            }
            \(access)var underlying\(name.prefix(1).uppercased() + name.dropFirst()): \(typeName)
            \(access)var \(name)Closure: (() async -> \(typeName))?
        """
    }

    // MARK: - Method Mock Generation

    private static func generateMethodMock(_ funcDecl: FunctionDeclSyntax, access: String) -> String {
        let methodName = funcDecl.name.trimmedDescription
        let params = Array(funcDecl.signature.parameterClause.parameters)
        let returnType = funcDecl.signature.returnClause?.type.trimmedDescription
        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrowing = funcDecl.signature.effectSpecifiers?.throwsClause != nil
        let isMainActor = funcDecl.attributes.contains {
            $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "MainActor"
        }

        let uniqueName = buildUniqueName(methodName: methodName, params: params)
        var lines: [String] = []

        lines.append("    //MARK: - \(methodName)")

        if isThrowing {
            lines.append("    \(access)var \(uniqueName)ThrowableError: Error?")
        }

        lines.append("    \(access)var \(uniqueName)CallsCount = 0")
        lines.append("""
            \(access)var \(uniqueName)Called: Bool {
                return \(uniqueName)CallsCount > 0
            }
        """)

        if params.count == 1 {
            let param = params[0]
            let paramName = effectiveParamName(param)
            let storedType = strippedType(param.type)
            let capitalizedParam = paramName.prefix(1).uppercased() + paramName.dropFirst()
            lines.append("    \(access)var \(uniqueName)Received\(capitalizedParam): \(makeOptional(storedType))")
            lines.append("    \(access)var \(uniqueName)ReceivedInvocations: [\(storedType)] = []")
        } else if params.count > 1 {
            let tupleType = params.map { "\(effectiveLabel($0)): \(strippedType($0.type))" }.joined(separator: ", ")
            lines.append("    \(access)var \(uniqueName)ReceivedArguments: (\(tupleType))?")
            lines.append("    \(access)var \(uniqueName)ReceivedInvocations: [(\(tupleType))] = []")
        }

        if let returnType {
            lines.append("    \(access)var \(uniqueName)ReturnValue: \(makeImplicitlyUnwrapped(returnType))")
        }

        let closureType = buildClosureType(params: params, returnType: returnType, isAsync: isAsync, isThrowing: isThrowing, isMainActor: isMainActor)
        lines.append("    \(access)var \(uniqueName)Closure: \(closureType)?")

        lines.append(buildMethodImpl(
            funcDecl: funcDecl,
            uniqueName: uniqueName,
            params: params,
            returnType: returnType,
            isAsync: isAsync,
            isThrowing: isThrowing,
            isMainActor: isMainActor,
            access: access
        ))

        return lines.joined(separator: "\n")
    }

    // MARK: - Unique Name

    private static func buildUniqueName(methodName: String, params: [FunctionParameterSyntax]) -> String {
        guard !params.isEmpty else { return methodName }
        var result = methodName
        for param in params {
            let firstName = param.firstName.trimmedDescription
            let label = firstName == "_" ? (param.secondName?.trimmedDescription ?? firstName) : firstName
            result += label.prefix(1).uppercased() + label.dropFirst()
            result += typeIdentifier(param.type)
        }
        return result
    }

    private static func typeIdentifier(_ type: TypeSyntax) -> String {
        let raw = type.trimmedDescription
        let filtered = raw.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        var str = String(filtered)
        guard !str.isEmpty else { return str }
        if isArrayType(type) { str += "s" }
        return str.prefix(1).uppercased() + str.dropFirst()
    }

    private static func isArrayType(_ type: TypeSyntax) -> Bool {
        if type.is(ArrayTypeSyntax.self) { return true }
        if let optional = type.as(OptionalTypeSyntax.self) {
            return isArrayType(optional.wrappedType)
        }
        if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return isArrayType(iuo.wrappedType)
        }
        return false
    }

    // MARK: - Closure Type

    private static func buildClosureType(
        params: [FunctionParameterSyntax],
        returnType: String?,
        isAsync: Bool,
        isThrowing: Bool,
        isMainActor: Bool
    ) -> String {
        let paramTypes = params.map { $0.type.trimmedDescription }.joined(separator: ", ")
        let ret = returnType ?? "()"
        var effectsStr = ""
        if isAsync { effectsStr += " async" }
        if isThrowing { effectsStr += " throws" }
        let mainActorPrefix = isMainActor ? "@MainActor\n" : ""
        return "(\(mainActorPrefix)(\(paramTypes))\(effectsStr) -> \(ret))"
    }

    // MARK: - Method Implementation

    private static func buildMethodImpl(
        funcDecl: FunctionDeclSyntax,
        uniqueName: String,
        params: [FunctionParameterSyntax],
        returnType: String?,
        isAsync: Bool,
        isThrowing: Bool,
        isMainActor: Bool,
        access: String
    ) -> String {
        let methodName = funcDecl.name.trimmedDescription
        let paramList = params.map { param -> String in
            let firstName = param.firstName.trimmedDescription
            let secondName = param.secondName?.trimmedDescription
            let type = param.type.trimmedDescription
            return secondName != nil ? "\(firstName) \(secondName!): \(type)" : "\(firstName): \(type)"
        }.joined(separator: ", ")

        var signature = ""
        if isMainActor { signature += "    @MainActor\n" }
        signature += "    \(access)func \(methodName)(\(paramList))"
        if isAsync { signature += " async" }
        if isThrowing { signature += " throws" }
        if let returnType { signature += " -> \(returnType)" }

        var body: [String] = []

        if isThrowing {
            body.append("        if let error = \(uniqueName)ThrowableError { throw error }")
        }
        body.append("        \(uniqueName)CallsCount += 1")

        if params.count == 1 {
            let param = params[0]
            let paramName = effectiveParamName(param)
            let capitalizedParam = paramName.prefix(1).uppercased() + paramName.dropFirst()
            let valueName = param.secondName?.trimmedDescription ?? param.firstName.trimmedDescription
            body.append("        \(uniqueName)Received\(capitalizedParam) = \(valueName)")
            body.append("        \(uniqueName)ReceivedInvocations.append(\(valueName))")
        } else if params.count > 1 {
            let argValues = params.map { "\(effectiveLabel($0)): \($0.secondName?.trimmedDescription ?? $0.firstName.trimmedDescription)" }.joined(separator: ", ")
            body.append("        \(uniqueName)ReceivedArguments = (\(argValues))")
            body.append("        \(uniqueName)ReceivedInvocations.append((\(argValues)))")
        }

        let callPrefix = (isThrowing ? "try " : "") + (isAsync ? "await " : "")
        let argNames = params.map { $0.secondName?.trimmedDescription ?? $0.firstName.trimmedDescription }.joined(separator: ", ")

        if returnType != nil {
            body.append("        if let \(uniqueName)Closure = \(uniqueName)Closure {")
            body.append("            return \(callPrefix)\(uniqueName)Closure(\(argNames))")
            body.append("        } else {")
            body.append("            return \(uniqueName)ReturnValue")
            body.append("        }")
        } else {
            body.append("        \(callPrefix)\(uniqueName)Closure?(\(argNames))")
        }

        return "\(signature) {\n\(body.joined(separator: "\n"))\n    }"
    }

    // MARK: - Helpers

    private static func effectiveParamName(_ param: FunctionParameterSyntax) -> String {
        let firstName = param.firstName.trimmedDescription
        if firstName == "_" { return param.secondName?.trimmedDescription ?? firstName }
        return param.secondName?.trimmedDescription ?? firstName
    }

    private static func effectiveLabel(_ param: FunctionParameterSyntax) -> String {
        let firstName = param.firstName.trimmedDescription
        if firstName == "_" { return param.secondName?.trimmedDescription ?? firstName }
        return firstName
    }

    private static func strippedType(_ type: TypeSyntax) -> String {
        var result = type.trimmedDescription
        result = result.replacingOccurrences(of: "@escaping ", with: "")
        result = result.replacingOccurrences(of: "@Sendable ", with: "")
        return result
    }

    private static func makeOptional(_ type: String) -> String {
        if type.hasSuffix("?") || type.hasSuffix("!") { return type }
        if type.hasPrefix("any ") { return "(\(type))?" }
        return "\(type)?"
    }

    private static func makeImplicitlyUnwrapped(_ type: String) -> String {
        if type.hasSuffix("?") || type.hasSuffix("!") { return type }
        if type.hasPrefix("any ") { return "(\(type))!" }
        return "\(type)!"
    }
}

// MARK: - ProtocolDeclSyntax helper

private extension ProtocolDeclSyntax {
    var accessLevelKeyword: String {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public): return "public "
            case .keyword(.package): return "package "
            case .keyword(.private): return "private "
            case .keyword(.fileprivate): return "fileprivate "
            default: continue
            }
        }
        return ""
    }
}
