import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct Injection {}

extension Injection: PeerMacro {
    public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                                 providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                                 in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax]
    {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw CamperMacrosError.injectionIncorrectType
        }

        let injectorType = protocolDecl.attributes.injectorType ?? "DefaultInjector"
        let addMock = protocolDecl.attributes.injectionArguments?.boolValue(label: "mock") ?? true
        let addBuild = protocolDecl.attributes.injectionArguments?.boolValue(label: "build") ?? false

        let name = protocolDecl.name.trimmed.text
        let implName = name + "Impl"
        let mockName = name + "Mock"
        let privacyModifier = protocolDecl.privacyModifier
        let parentInjection = protocolDecl.parentInjectionProtocol

        guard name.hasSuffix("Injection") else { throw CamperMacrosError.injectionIncorrectName }

        var result: [DeclSyntax] = []

        // MARK: - *Impl

        if let parentInjection {
            result.append(makeInheritedImplDecl(
                name: name, implName: implName,
                privacyModifier: privacyModifier,
                parentInjection: parentInjection,
                variables: protocolDecl.allVariables
            ))
        } else {
            result.append(try makeRootImplDecl(
                name: name, implName: implName,
                injectorType: injectorType,
                privacyModifier: privacyModifier,
                variables: protocolDecl.allVariables
            ))
        }

        // MARK: - *Mock

        if addMock {
            if let parentInjection {
                result.append(makeInheritedMockDecl(
                    name: name, mockName: mockName,
                    privacyModifier: privacyModifier,
                    parentInjection: parentInjection,
                    variables: protocolDecl.allVariables
                ))
            } else {
                result.append(try makeRootMockDecl(
                    name: name, mockName: mockName,
                    privacyModifier: privacyModifier,
                    variables: protocolDecl.allVariables
                ))
            }
        }

        // MARK: - build(injector:)

        if addBuild {
            let buildFunc = try FunctionDeclSyntax("func build(injector: \(raw: injectorType)) -> \(raw: name)") {
                "\(raw: implName)(injector: injector)"
            }
            result.append(DeclSyntax(buildFunc))
        }

        return result
    }
}

// MARK: - Root *Impl

private extension Injection {
    static func makeRootImplDecl(
        name: String,
        implName: String,
        injectorType: String,
        privacyModifier: String,
        variables: [VariableDeclSyntax]
    ) throws -> DeclSyntax {
        let implDecl = try ClassDeclSyntax(
            "\(raw: privacyModifier) final class \(raw: implName): \(raw: name), PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable"
        ) {
            "private var __passedObjects: [String: WeakRef] = [:]"
            "private weak var parent: PassedObjectsInjection?"
            "private let injector: \(raw: injectorType)"

            DeclSyntax("\(raw: privacyModifier) var description: String { \"\\(type(of: self)) -> \\(parent != nil ? String(describing: parent!) : \"nil\")\" }")

            try InitializerDeclSyntax(
                "\(raw: privacyModifier) init(injector: \(raw: injectorType), parent: PassedObjectsInjection? = nil)"
            ) {
                "self.injector = injector"
                "self.parent = parent"
            }

            try FunctionDeclSyntax(
                "\(raw: privacyModifier) func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject"
            ) {
                "return __passedObjects[\"\\(ObjectType.self)\"]?.value as? ObjectType ?? parent?.getPassedObject()"
            }

            try FunctionDeclSyntax(
                "\(raw: privacyModifier) func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject"
            ) {
                "__passedObjects[\"\\(ObjectType.self)\"] = object != nil ? WeakRef(object!) : nil"
            }

            for variable in variables {
                if let origin = variable.originPath {
                    "var \(raw: variable.identifier): \(raw: variable.rawIdentifierType) { injector.\(raw: origin) }"
                } else if variable.rawIdentifierType.hasSuffix("Injection") {
                    "var \(raw: variable.identifier): \(raw: variable.rawIdentifierType) { \(raw: variable.rawIdentifierType)Impl(injector: injector, parent: self) }"
                } else if variable.isPassed {
                    "var \(raw: variable.identifier): \(raw: variable.rawIdentifierType) { get { getPassedObject() } set { setPassedObject(newValue) } }"
                } else {
                    "var \(raw: variable.identifier): \(raw: variable.rawIdentifierType) { injector.\(raw: variable.identifier) }"
                }
            }
        }
        return DeclSyntax(implDecl)
    }
}

// MARK: - Inherited *Impl

private extension Injection {
    static func makeInheritedImplDecl(
        name: String,
        implName: String,
        privacyModifier: String,
        parentInjection: String,
        variables: [VariableDeclSyntax]
    ) -> DeclSyntax {
        let parentImplName = "\(parentInjection)Impl"
        let lines = variables.map { implLine($0) }
        let body = lines.isEmpty ? "" : "\n" + lines.joined(separator: "\n") + "\n"
        return DeclSyntax(stringLiteral: "\(privacyModifier) class \(implName): \(parentImplName), \(name) {\(body)}")
    }

    static func implLine(_ variable: VariableDeclSyntax) -> String {
        let n = variable.identifier
        let t = variable.rawIdentifierType
        if let origin = variable.originPath { return "    var \(n): \(t) { injector.\(origin) }" }
        if t.hasSuffix("Injection") { return "    var \(n): \(t) { \(t)Impl(injector: injector, parent: self) }" }
        if variable.isPassed { return "    var \(n): \(t) { get { getPassedObject() } set { setPassedObject(newValue) } }" }
        return "    var \(n): \(t) { injector.\(n) }"
    }
}

// MARK: - Root *Mock

private extension Injection {
    static func makeRootMockDecl(
        name: String,
        mockName: String,
        privacyModifier: String,
        variables: [VariableDeclSyntax]
    ) throws -> DeclSyntax {
        let mockDecl = try ClassDeclSyntax(
            "\(raw: privacyModifier) final class \(raw: mockName): \(raw: name), @unchecked Sendable"
        ) {
            for variable in variables {
                if variable.rawIdentifierType.hasSuffix("Injection") {
                    "var \(raw: variable.identifier): \(raw: variable.rawIdentifierType) { \(raw: variable.rawIdentifierType)Mock() }"
                } else {
                    "var _\(raw: variable.identifier): \(raw: variable.rawIdentifierType)!"
                    "var \(raw: variable.identifier): \(raw: variable.rawIdentifierType) { _\(raw: variable.identifier) }"
                }
            }
        }
        return DeclSyntax(mockDecl)
    }
}

// MARK: - Inherited *Mock

private extension Injection {
    static func makeInheritedMockDecl(
        name: String,
        mockName: String,
        privacyModifier: String,
        parentInjection: String,
        variables: [VariableDeclSyntax]
    ) -> DeclSyntax {
        let parentMockName = "\(parentInjection)Mock"
        let lines = variables.map { mockLine($0) }
        let body = lines.isEmpty ? "" : "\n" + lines.joined(separator: "\n") + "\n"
        return DeclSyntax(stringLiteral: "\(privacyModifier) class \(mockName): \(parentMockName), \(name) {\(body)}")
    }

    static func mockLine(_ variable: VariableDeclSyntax) -> String {
        let n = variable.identifier
        let t = variable.rawIdentifierType
        if t.hasSuffix("Injection") { return "    var \(n): \(t) { \(t)Mock() }" }
        return "    var _\(n): \(t)!\n    var \(n): \(t) { _\(n) }"
    }
}
