import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct Injector {}

extension Injector: PeerMacro {
    public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                                 providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax]
    {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else { throw CamperMacrosError.injectorIncorrectType }
        var result: [SwiftSyntax.DeclSyntax] = []
        let className = classDecl.name.text

        if classDecl.attributes.injectorArguments?.boolValue(label: "mock") != false {
            let regularDeps = classDecl.allVariables.filter { $0.isDependency && !$0.isExplicitDependency }
            let explicitDeps = classDecl.allVariables.filter { $0.isExplicitDependency }

            let mockFuncDecl: DeclSyntax
            let explicitArgs = explicitDeps.compactMap { v -> String? in
                let t = v.rawIdentifierType
                guard !t.isEmpty else { return nil }
                let mockType = t + "Mock"
                return "\(v.identifier): \(mockType).mock()"
            }.joined(separator: ", ")

            if regularDeps.isEmpty && explicitDeps.isEmpty {
                mockFuncDecl = DeclSyntax("\(raw: classDecl.privacyModifier) static func mock() -> \(raw: className) { \(raw: className)() }")
            } else if regularDeps.isEmpty {
                mockFuncDecl = DeclSyntax("\(raw: classDecl.privacyModifier) static func mock() -> \(raw: className) { \(raw: className)(\(raw: explicitArgs)) }")
            } else if explicitDeps.isEmpty {
                let fn = try FunctionDeclSyntax("\(raw: classDecl.privacyModifier) static func mock(configure: (\(raw: className).DependenciesMock) -> Void = { _ in }) -> \(raw: className)") {
                    "let deps = \(raw: className).DependenciesMock()"
                    "configure(deps)"
                    "return \(raw: className)(dependencies: deps)"
                }
                mockFuncDecl = DeclSyntax(fn)
            } else {
                let fn = try FunctionDeclSyntax("\(raw: classDecl.privacyModifier) static func mock(configure: (\(raw: className).DependenciesMock) -> Void = { _ in }) -> \(raw: className)") {
                    "let deps = \(raw: className).DependenciesMock()"
                    "configure(deps)"
                    "return \(raw: className)(dependencies: deps, \(raw: explicitArgs))"
                }
                mockFuncDecl = DeclSyntax(fn)
            }

            let mock = try EnumDeclSyntax("\(raw: classDecl.privacyModifier) enum \(raw: className)Mock") {
                mockFuncDecl
            }
            result.append(DeclSyntax(mock))
        }

        result.append(DeclSyntax(stringLiteral: "typealias DefaultInjector = \(className)"))
        return result
    }
}

extension Injector: MemberMacro {
    public static func expansion(of _: AttributeSyntax,
                                 providingMembersOf declaration: some DeclGroupSyntax,
                                 conformingTo _: [TypeSyntax],
                                 in _: some MacroExpansionContext) throws -> [DeclSyntax]
    {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else { throw CamperMacrosError.injectorIncorrectType }
        let privacyModifier = classDecl.privacyModifier

        let outputs = classDecl.allVariables.filter { $0.isOutput && !$0.isInternalOutput }
        let subscripts = classDecl.allVariables.filter { $0.isSubscriptDependency || $0.isSubscriptOutput }
        let regularDeps = classDecl.allVariables.filter { $0.isDependency && !$0.isExplicitDependency }
        let explicitDeps = classDecl.allVariables.filter { $0.isExplicitDependency }
        let hasSetup = classDecl.allFunctions.contains(where: { $0.isSetup })
        let setupCall = hasSetup ? "setup()" : ""

        var result: [DeclSyntax] = []

        // MARK: Outputs protocol

        let outputsProtocol = try ProtocolDeclSyntax("\(raw: privacyModifier) protocol Outputs") {
            for variable in outputs {
                let typeString = variable.rawIdentifierType
                if !typeString.isEmpty {
                    "var \(raw: variable.identifier): \(raw: typeString) { get }"
                }
            }
            for variable in outputs {
                let typeString = variable.rawIdentifierType
                if !typeString.isEmpty {
                    "func getValue() -> \(raw: typeString)"
                }
            }
        }
        result.append(DeclSyntax(outputsProtocol))

        // MARK: Dependencies protocol (regular only)

        if !regularDeps.isEmpty {
            let dependenciesProtocol = try ProtocolDeclSyntax("\(raw: privacyModifier) protocol Dependencies") {
                for variable in regularDeps {
                    let typeString = variable.rawIdentifierType
                    if !typeString.isEmpty {
                        "var \(raw: variable.identifier): \(raw: typeString) { get }"
                    }
                }
            }
            result.append(DeclSyntax(dependenciesProtocol))
            result.append(DeclSyntax("private let dependencies: Dependencies"))
        }

        // MARK: _ExplicitDependencies struct

        if !explicitDeps.isEmpty {
            let structBody = explicitDeps.compactMap { v -> String? in
                let t = v.rawIdentifierType
                guard !t.isEmpty else { return nil }
                return "    let \(v.identifier): \(t)"
            }.joined(separator: "\n")
            result.append(DeclSyntax(stringLiteral: "private struct _ExplicitDependencies {\n\(structBody)\n}"))
            result.append(DeclSyntax("private let _explicitDependencies: _ExplicitDependencies"))
        }

        // MARK: init

        var initParams: [String] = []
        var initBodyLines: [String] = []

        if !regularDeps.isEmpty {
            initParams.append("dependencies: Dependencies")
            initBodyLines.append("self.dependencies = dependencies")
        }

        for v in explicitDeps {
            let t = v.rawIdentifierType
            guard !t.isEmpty else { continue }
            initParams.append("\(v.identifier): \(t)")
        }

        if !explicitDeps.isEmpty {
            let args = explicitDeps.map { "\($0.identifier): \($0.identifier)" }.joined(separator: ", ")
            initBodyLines.append("self._explicitDependencies = _ExplicitDependencies(\(args))")
        }

        if !setupCall.isEmpty {
            initBodyLines.append(setupCall)
        }

        if initParams.isEmpty {
            result.append(DeclSyntax("\(raw: privacyModifier) init() { \(raw: setupCall) }"))
        } else {
            let params = initParams.joined(separator: ", ")
            let body = initBodyLines.map { "    \($0)" }.joined(separator: "\n")
            result.append(DeclSyntax(stringLiteral: "\(privacyModifier) init(\(params)) {\n\(body)\n}"))
        }

        // MARK: getValue() for each output/dependency

        for variable in classDecl.allVariables {
            guard variable.isDependency || variable.isOutput else { continue }
            let typeString = variable.rawIdentifierType
            if !typeString.isEmpty {
                let modifier = variable.isInternalOutput ? "" : "\(privacyModifier) "
                let getValueFunc = try FunctionDeclSyntax("\(raw: modifier)func getValue() -> \(raw: typeString)") {
                    "\(raw: variable.identifier)"
                }
                result.append(DeclSyntax(getValueFunc))
            }
        }

        // MARK: subscript(dynamicMember:)

        if !subscripts.isEmpty {
            guard classDecl.attributes.contains(named: "dynamicMemberLookup") else {
                throw CamperMacrosError.injectorNonDynamicType
            }
            for variable in subscripts {
                let typeString = variable.rawIdentifierType
                let modifier = variable.readPrivacyModifier
                if !typeString.isEmpty {
                    result.append(DeclSyntax(
                        "\(raw: modifier) subscript<T>(dynamicMember keyPath: KeyPath<\(raw: typeString), T>) -> T { \(raw: variable.identifier)[keyPath: keyPath] }"
                    ))
                }
            }
        }

        return result
    }
}

extension Injector: ExtensionMacro {
    public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                                 attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                                 providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
                                 conformingTo _: [SwiftSyntax.TypeSyntax],
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.ExtensionDeclSyntax]
    {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else { throw CamperMacrosError.injectorIncorrectType }
        guard
            classDecl.attributes.injectorArguments?.boolValue(label: "dependenciesMock") != false ||
            classDecl.attributes.injectorArguments?.boolValue(label: "mock") != false
        else { return [] }

        let className = type.trimmed
        let privacyModifier = classDecl.privacyModifier
        let regularDeps = classDecl.allVariables.filter { $0.isDependency && !$0.isExplicitDependency }
        let addMock = classDecl.attributes.injectorArguments?.boolValue(label: "mock") != false

        var members: [DeclSyntax] = []

        if addMock {
            if regularDeps.isEmpty {
                let mockFunc = try FunctionDeclSyntax(
                    "\(raw: privacyModifier) static func mock() -> \(raw: className)"
                ) {
                    "\(raw: className)Mock.mock()"
                }
                members.append(DeclSyntax(mockFunc))
            } else {
                let mockFunc = try FunctionDeclSyntax(
                    "\(raw: privacyModifier) static func mock(configure: (DependenciesMock) -> Void = { _ in }) -> \(raw: className)"
                ) {
                    "\(raw: className)Mock.mock(configure: configure)"
                }
                members.append(DeclSyntax(mockFunc))
            }
        }

        if !regularDeps.isEmpty {
            let depsMock = try ClassDeclSyntax("\(raw: privacyModifier) final class DependenciesMock: \(raw: className).Dependencies") {
                for variable in regularDeps {
                    let typeString = variable.rawIdentifierType
                    if !typeString.isEmpty {
                        let mockType = typeString.replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "")
                        "\(raw: privacyModifier) var \(raw: variable.identifier): \(raw: typeString) = \(raw: mockType)Mock.mock()"
                    }
                }
            }
            members.append(DeclSyntax(depsMock))
        }

        guard !members.isEmpty else { return [] }

        return [
            ExtensionDeclSyntax(
                extendedType: TypeSyntax("\(raw: className)"),
                memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax(members.map { MemberBlockItemSyntax(decl: $0) }))
            )
        ]
    }
}
