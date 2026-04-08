import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum IOModel {
    // MARK: - Insert/Unique funcs

    static func insertFuncsSyntax(with classDecl: ClassDeclSyntax) throws -> [DeclSyntax] {
        let className = classDecl.name.text
        let privacyModifier = classDecl.privacyModifier

        var result: [DeclSyntax] = []

        if let unique = classDecl.uniqueVariable {
            let uniqueName = unique.identifier
            let uniqueType = unique.rawIdentifierType

            let uniqueSyntax = try FunctionDeclSyntax("\(raw: privacyModifier) class func unique(_ value: \(raw: uniqueType), in context: ModelContext) throws -> \(raw: className)?") {
                "var descriptor = FetchDescriptor<\(raw: className)>(predicate: #Predicate { $0.\(raw: uniqueName) == value })"
                "descriptor.fetchLimit = 1"
                "descriptor.includePendingChanges = true"
                "return try context.fetch(descriptor).first"
            }
            result.append(DeclSyntax(uniqueSyntax))

            let uniqueArraySyntax = try FunctionDeclSyntax("\(raw: privacyModifier) class func unique(_ values: [\(raw: uniqueType)], in context: ModelContext) throws -> [\(raw: className)]") {
                "try values.compactMap { try unique($0, in: context) }"
            }
            result.append(DeclSyntax(uniqueArraySyntax))

            let deleteSyntax = try FunctionDeclSyntax("@discardableResult \(raw: privacyModifier) class func delete(_ value: \(raw: uniqueType), in context: ModelContext) throws -> \(raw: className)?") {
                "let model = try unique(value, in: context)"
                "if let model { context.delete(model) }"
                "return model"
            }
            result.append(DeclSyntax(deleteSyntax))

            let deleteArraySyntax = try FunctionDeclSyntax("@discardableResult \(raw: privacyModifier) class func delete(_ values: [\(raw: uniqueType)], in context: ModelContext) throws -> [\(raw: className)]") {
                "try values.compactMap { try delete($0, in: context) }"
            }
            result.append(DeclSyntax(deleteArraySyntax))
        }

        let insertSyntax = try FunctionDeclSyntax("@discardableResult \(raw: privacyModifier) class func insert(_ input: \(raw: className.asInputModel), in context: ModelContext) throws -> \(raw: className)") {
            "let result: \(raw: className)"

            if let unique = classDecl.uniqueVariable {
                let uniqueName = unique.identifier

                try IfExprSyntax("if let exist = try unique(input.\(raw: uniqueName), in: context)") {
                    "result = exist"
                    for varDecl in classDecl.inputWritableVariables {
                        if varDecl.isIgnorable {
                            try SwitchExprSyntax("switch input.\(raw: varDecl.identifier)") {
                                "case .ignore: break"
                                "case .value(let value): result.\(raw: varDecl.identifier) = value"
                            }
                        } else if !varDecl.isRelationship {
                            "result.\(raw: varDecl.identifier) = input.\(raw: varDecl.identifier)"
                        } else if varDecl.isNonLinkable {
                            try SwitchExprSyntax("switch input.\(raw: varDecl.identifier)") {
                                "case .ignore: break"
                                "case .value(let value): result.\(raw: varDecl.identifier) = value"
                                if varDecl.isOptional, !varDecl.isArray {
                                    """
                                    case .input(let value):
                                        if let old = result.\(raw: varDecl.identifier) { context.delete(old) }
                                        result.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).insert(value, in: context)
                                    """
                                    """
                                    case .update(let value):
                                        if let existing = result.\(raw: varDecl.identifier) { try existing.update(input: value) }
                                        else { let new = try \(raw: varDecl.elementIdentifierType)(input: value, context: context); context.insert(new); result.\(raw: varDecl.identifier) = new }
                                    """
                                } else if varDecl.isArray {
                                    """
                                    case .input(let value):
                                        result.\(raw: varDecl.identifier)\(raw: varDecl.isOptional ? "?" : "").forEach { context.delete($0) }
                                        result.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).insert(value, in: context)
                                    """
                                }
                            }
                        } else {
                            try SwitchExprSyntax("switch input.\(raw: varDecl.identifier)") {
                                "case .ignore: break"
                                "case .value(let value): result.\(raw: varDecl.identifier) = value"
                                "case .link(let value): result.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).unique(value, in: context)"
                                "case .input(let value): result.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).insert(value, in: context)"
                            }
                        }
                    }

                } else: {
                    "result = try \(raw: className)(input: input, context: context)"
                    "context.insert(result)"
                }
            } else {
                "result = try \(raw: className)(input: input, context: context)"
                "context.insert(result)"
            }
            "return result"
        }
        result.append(DeclSyntax(insertSyntax))

        let insertArraySyntax = try FunctionDeclSyntax("@discardableResult \(raw: privacyModifier) class func insert(_ inputs: [\(raw: className.asInputModel)], in context: ModelContext) throws -> [\(raw: className)]") {
            "try inputs.map { try insert($0, in: context) }"
        }

        result.append(DeclSyntax(insertArraySyntax))

        if let unique = classDecl.uniqueVariable {
            let uniqueName = unique.identifier

            let replaceSyntax = try FunctionDeclSyntax("@discardableResult \(raw: privacyModifier) class func replace(_ inputs: [\(raw: className.asInputModel)], in context: ModelContext) throws -> [\(raw: className)]") {
                "let inserted = try inputs.map { try insert($0, in: context) }"
                "let insertedIDs = inputs.map { $0.\(raw: uniqueName) }"
                "let descriptor = FetchDescriptor<\(raw: className)>(predicate: #Predicate { !insertedIDs.contains($0.\(raw: uniqueName)) })"
                "for item in try context.fetch(descriptor) { context.delete(item) }"
                "return inserted"
            }
            result.append(DeclSyntax(replaceSyntax))
        }

        return result
    }

    static func uniqueConformanceSyntax(with classDecl: ClassDeclSyntax) -> [DeclSyntax] {
        guard let uniqueVar = classDecl.uniqueVariable else { return [] }

        let syntaxString =
            """
                \(classDecl.privacyModifier) typealias UniqueID = \(uniqueVar.elementIdentifierType)

                @_implements(UniqueFindable, uniqueValue)
                \(classDecl.privacyModifier) var _uniqueValue\(uniqueVar.identifier.firstCapitalized): UniqueID { \(uniqueVar.identifier) }

            """
        return [
            DeclSyntax(stringLiteral: syntaxString),
        ]
    }

    // MARK: - Input Enums

    static func attributeEnumsSyntax(with classDecl: ClassDeclSyntax) throws -> [DeclSyntax] {
        var result: [DeclSyntax] = []

        for varDecl in classDecl.inputVariables {
            guard varDecl.isRelationship else { continue }
            let enumName = varDecl.identifier.asInputEnum

            let enumDecl = try EnumDeclSyntax("\(raw: classDecl.privacyModifier) enum \(raw: enumName): Codable") {
                "case ignore"
                "case value(_ value: \(raw: varDecl.rawIdentifierType))"
                "case input(_ value: \(raw: varDecl.inputModelIdentifierType))"
                if varDecl.isNonLinkable, !varDecl.isArray {
                    "case update(_ value: \(raw: varDecl.inputModelIdentifierType))"
                }
                if !varDecl.isNonLinkable {
                    "case link(_ value: \(raw: varDecl.linkIdentifierType))"
                }

                try FunctionDeclSyntax("\(raw: classDecl.privacyModifier) func encode(to encoder: any Encoder) throws") {
                    "var container = encoder.singleValueContainer()"
                    try SwitchExprSyntax("switch self") {
                        "case .ignore: break"
                        if !varDecl.isNonLinkable {
                            "case .link(let value): try container.encode(value)"
                        }
                        if varDecl.isArray {
                            "case .input(let value): try container.encode(value.map { \(raw: varDecl.elementIdentifierType).Snapshot($0) })"
                            "case .value(let value): try container.encode(value\(raw: varDecl.isOptional ? "?" : "").map { $0.snapshot() })"
                        } else {
                            "case .input(let value): try container.encode(\(raw: varDecl.elementIdentifierType).Snapshot(value))"
                            if varDecl.isNonLinkable {
                                "case .update(let value): try container.encode(\(raw: varDecl.elementIdentifierType).Snapshot(value))"
                            }
                            "case .value(let value): try container.encode(value\(raw: varDecl.isOptional ? "?" : "").snapshot())"
                        }
                    }
                }

                try InitializerDeclSyntax("\(raw: classDecl.privacyModifier) init(from decoder: any Decoder) throws") {
                    "let values = try decoder.singleValueContainer()"

                    var stmt = try DoStmtSyntax("do") {
                        if varDecl.isArray {
                            "let value = try values.decode([\(raw: varDecl.elementIdentifierType).Snapshot].self)"
                        } else {
                            "let value = try values.decode(\(raw: varDecl.elementIdentifierType).Snapshot.self)"
                        }
                        "self = .input(value)"
                    }

                    if !varDecl.isNonLinkable {
                        let catchStmt = CatchClauseSyntax("catch") {
                            if varDecl.isArray {
                                "let value = try values.decode([\(raw: varDecl.elementIdentifierType).UniqueID].self)"
                            } else {
                                "let value = try values.decode(\(raw: varDecl.elementIdentifierType).UniqueID.self)"
                            }
                            "self = .link(value)"
                        }

                        let _ = stmt.catchClauses.append(catchStmt)
                    }

                    stmt
                }
            }
            result.append(DeclSyntax(enumDecl))
        }

        for varDecl in classDecl.inputVariables {
            guard varDecl.isIgnorable else { continue }
            let enumName = varDecl.identifier.asInputEnum

            let enumDecl = try EnumDeclSyntax("\(raw: classDecl.privacyModifier) enum \(raw: enumName): Codable") {
                "case ignore"
                "case value(_ value: \(raw: varDecl.rawIdentifierType))"

                try FunctionDeclSyntax("\(raw: classDecl.privacyModifier) func encode(to encoder: any Encoder) throws") {
                    "var container = encoder.singleValueContainer()"
                    try SwitchExprSyntax("switch self") {
                        "case .ignore: break"
                        "case .value(let value): try container.encode(value)"
                    }
                }

                try InitializerDeclSyntax("\(raw: classDecl.privacyModifier) init(from decoder: any Decoder) throws") {
                    "let values = try decoder.singleValueContainer()"
                    "let value = try values.decode(\(raw: varDecl.rawIdentifierType).self)"
                    "self = .value(value)"
                }
            }
            result.append(DeclSyntax(enumDecl))
        }

        return result
    }

    // MARK: - InputProtocol

    static func inputProtocolSyntax(with classDecl: ClassDeclSyntax) throws -> DeclSyntax {
        let className = classDecl.name.text

        let protoDecl = try ProtocolDeclSyntax("\(raw: classDecl.privacyModifier) protocol InputModel: Sendable") {
            for varSyntax in classDecl.inputVariables {
                "var \(raw: varSyntax.identifier): \(raw: varSyntax.inputProtocolIdentifierType(className: className)) { get }"
            }
        }

        return DeclSyntax(protoDecl)
    }

    // MARK: - Init & Update

    static func initWithInputSyntax(with classDecl: ClassDeclSyntax) throws -> DeclSyntax {
        let className = classDecl.name.text

        let initSyntax = try InitializerDeclSyntax("\(raw: classDecl.privacyModifier) init(input: \(raw: className.asInputModel), context: ModelContext) throws") {
            for varDecl in classDecl.inputVariables {
                if varDecl.isIgnorable {
                    let ignoreAction = varDecl.initializerValue.map { "self.\(varDecl.identifier) = \($0)" } ?? "break"
                    try SwitchExprSyntax("switch input.\(raw: varDecl.identifier)") {
                        "case .ignore: \(raw: ignoreAction)"
                        "case .value(let value): self.\(raw: varDecl.identifier) = value"
                    }
                } else if !varDecl.isRelationship {
                    "self.\(raw: varDecl.identifier) = input.\(raw: varDecl.identifier)"
                } else {
                    try SwitchExprSyntax("switch input.\(raw: varDecl.identifier)") {
                        "case .ignore: break"
                        "case .value(let value): self.\(raw: varDecl.identifier) = value"
                        if !varDecl.isNonLinkable {
                            "case .link(let value): self.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).unique(value, in: context)"
                        }
                        "case .input(let value): self.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).insert(value, in: context)"
                        if varDecl.isNonLinkable, !varDecl.isArray {
                            "case .update(let value): self.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).insert(value, in: context)"
                        }
                    }
                }
            }
        }
        return DeclSyntax(initSyntax)
    }

    static func updateWithInputSyntax(with classDecl: ClassDeclSyntax) throws -> DeclSyntax {
        let className = classDecl.name.text

        let updateSyntax = try FunctionDeclSyntax("\(raw: classDecl.privacyModifier) func update(input: \(raw: className.asInputModel)) throws") {
            let vars = classDecl.inputWritableVariables
            if classDecl.attributes.first(named: "Model") != nil, vars.contains(where: { $0.isRelationship }) {
                "guard let context = modelContext else { return } "
            }

            for varDecl in vars where !varDecl.isConstant {
                if varDecl.isIgnorable {
                    try SwitchExprSyntax("switch input.\(raw: varDecl.identifier)") {
                        "case .ignore: break"
                        "case .value(let value): self.\(raw: varDecl.identifier) = value"
                    }
                } else if !varDecl.isRelationship {
                    "self.\(raw: varDecl.identifier) = input.\(raw: varDecl.identifier)"
                } else if varDecl.isNonLinkable {
                    try SwitchExprSyntax("switch input.\(raw: varDecl.identifier)") {
                        "case .ignore: break"
                        "case .value(let value): self.\(raw: varDecl.identifier) = value"
                        if varDecl.isOptional, !varDecl.isArray {
                            """
                            case .input(let value):
                                if let old = self.\(raw: varDecl.identifier) { context.delete(old) }
                                self.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).insert(value, in: context)
                            """
                            """
                            case .update(let value):
                                if let existing = self.\(raw: varDecl.identifier) { try existing.update(input: value) }
                                else { let new = try \(raw: varDecl.elementIdentifierType)(input: value, context: context); context.insert(new); self.\(raw: varDecl.identifier) = new }
                            """
                        } else if varDecl.isArray {
                            """
                            case .input(let value):
                                self.\(raw: varDecl.identifier)\(raw: varDecl.isOptional ? "?" : "").forEach { context.delete($0) }
                                self.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).insert(value, in: context)
                            """
                        }
                    }
                } else {
                    try SwitchExprSyntax("switch input.\(raw: varDecl.identifier)") {
                        "case .ignore: break"
                        "case .value(let value): self.\(raw: varDecl.identifier) = value"
                        "case .link(let value): self.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).unique(value, in: context)"
                        "case .input(let value): self.\(raw: varDecl.identifier) = try \(raw: varDecl.elementIdentifierType).insert(value, in: context)"
                    }
                }
            }
        }
        return DeclSyntax(updateSyntax)
    }

    // MARK: - Snapshot

    static func snapshotDeclSyntax(with classDecl: ClassDeclSyntax) throws -> DeclSyntax {
        let className = classDecl.name.text
        let inputVariables = classDecl.inputVariables
        let computedVariables = classDecl.computedVariables
        let privacyModifier = classDecl.privacyModifier

        let initArgs = inputVariables.map {
            let defaultValue = $0.defaultValue.map { " = \($0)" } ?? ($0.isOptional ? " = nil" : "")
            return "\($0.identifier): \($0.inputProtocolIdentifierType(className: className))\(defaultValue)"
        }.joined(separator: ", ")

        let snapshotDecl = try StructDeclSyntax("\(raw: privacyModifier) struct Snapshot: \(raw: className.asInputModel), Codable, @unchecked Sendable") {
            for varSyntax in inputVariables {
                if varSyntax.isRelationship || varSyntax.isIgnorable {
                    "\(raw: privacyModifier) var \(raw: varSyntax.identifier): \(raw: varSyntax.inputProtocolIdentifierType(className: className)) = .ignore"
                } else {
                    "\(raw: privacyModifier) var \(raw: varSyntax.identifier): \(raw: varSyntax.inputProtocolIdentifierType(className: className))"
                }
            }

            for varSyntax in computedVariables {
                "\(raw: privacyModifier) var \(raw: varSyntax.identifier): \(raw: varSyntax.unwrappedIdentifierType)? = nil"
            }

            try InitializerDeclSyntax("\(raw: privacyModifier) init(\(raw: initArgs))") {
                for varSyntax in inputVariables {
                    "self.\(raw: varSyntax.identifier) = \(raw: varSyntax.identifier)"
                }
            }

            try InitializerDeclSyntax("\(raw: privacyModifier) init(_ input: \(raw: className.asInputModel))") {
                for varSyntax in inputVariables {
                    "self.\(raw: varSyntax.identifier) = input.\(raw: varSyntax.identifier)"
                }
            }

            try snapshotCodingKeysSyntax(with: classDecl)
            try snapshotEncodableSyntax(with: classDecl)
            try snapshotDecodableSyntax(with: classDecl)
        }

        return DeclSyntax(snapshotDecl)
    }

    private static func snapshotCodingKeysSyntax(with classDecl: ClassDeclSyntax) throws -> EnumDeclSyntax {
        let variables = classDecl.inputVariables
        let computedVariables = classDecl.computedVariables
        return try EnumDeclSyntax("private enum CodingKeys: CodingKey") {
            for varDecl in variables {
                "case \(raw: varDecl.identifier)"
            }
            for varDecl in computedVariables {
                "case \(raw: varDecl.identifier)"
            }
        }
    }

    private static func snapshotEncodableSyntax(with classDecl: ClassDeclSyntax) throws -> FunctionDeclSyntax {
        let variables = classDecl.inputVariables
        let computedVariables = classDecl.computedVariables

        return try FunctionDeclSyntax("\(raw: classDecl.privacyModifier) func encode(to encoder: any Encoder) throws") {
            "var container = encoder.container(keyedBy: CodingKeys.self)"
            for varDecl in variables {
                if varDecl.isRelationship || varDecl.isIgnorable {
                    try SwitchExprSyntax("switch \(raw: varDecl.identifier)") {
                        "case .ignore: break"
                        "default: try container.encode(\(raw: varDecl.identifier), forKey: .\(raw: varDecl.identifier))"
                    }
                } else {
                    "try container.encode(\(raw: varDecl.identifier), forKey: .\(raw: varDecl.identifier))"
                }
            }
            for varDecl in computedVariables {
                "try container.encodeIfPresent(\(raw: varDecl.identifier), forKey: .\(raw: varDecl.identifier))"
            }
        }
    }

    private static func snapshotDecodableSyntax(with classDecl: ClassDeclSyntax) throws -> InitializerDeclSyntax {
        let variables = classDecl.inputVariables
        let computedVariables = classDecl.computedVariables
        let className = classDecl.name.text

        return try InitializerDeclSyntax("\(raw: classDecl.privacyModifier) init(from decoder: any Decoder) throws") {
            "let values = try decoder.container(keyedBy: CodingKeys.self)"
            for varDecl in variables {
                if varDecl.isRelationship || varDecl.isIgnorable {
                    let varType = varDecl.inputProtocolIdentifierType(className: className)
                    "self.\(raw: varDecl.identifier) = try values.decodeIfPresent(\(raw: varType).self, forKey: .\(raw: varDecl.identifier)) ?? .ignore"
                } else if varDecl.isOptional {
                    "self.\(raw: varDecl.identifier) = try values.decodeIfPresent(\(raw: varDecl.unwrappedIdentifierType).self, forKey: .\(raw: varDecl.identifier))"
                } else {
                    "self.\(raw: varDecl.identifier) = try values.decode(\(raw: varDecl.rawIdentifierType).self, forKey: .\(raw: varDecl.identifier))"
                }
            }
            for varDecl in computedVariables {
                "self.\(raw: varDecl.identifier) = try values.decodeIfPresent(\(raw: varDecl.unwrappedIdentifierType).self, forKey: .\(raw: varDecl.identifier))"
            }
        }
    }

    static func createSnapshotSyntax(with classDecl: ClassDeclSyntax) throws -> DeclSyntax {
        let linkInitValue = { (variable: VariableDeclSyntax) in
            if variable.isIgnorable {
                return "\(variable.identifier): .value(\(variable.identifier))"
            }

            let linkValue: String
            switch (variable.isNonLinkable, variable.isOptional, variable.isArray) {
            case (true, _, _): linkValue = ".ignore"
            case (false, true, false): linkValue = "\(variable.identifier).map { .link($0.uniqueValue) } ?? .ignore"
            case (false, false, false): linkValue = ".link(\(variable.identifier).uniqueValue)"
            case (false, true, true): linkValue = ".link(\(variable.identifier)?.map { $0.uniqueValue } ?? [])"
            case (false, false, true): linkValue = ".link(\(variable.identifier).map { $0.uniqueValue })"
            }

            return "\(variable.identifier): \(variable.isRelationship ? linkValue : variable.identifier)"
        }

        let ignoreInitValue = { (variable: VariableDeclSyntax) -> String in
            if variable.isIgnorable {
                return "\(variable.identifier): .value(\(variable.identifier))"
            }
            return "\(variable.identifier): \(variable.isRelationship ? ".ignore" : variable.identifier)"
        }
        
        let initArgs = classDecl.inputVariables.map { ignoreInitValue($0) }.joined(separator: ", ")
        let initLinksArgs = classDecl.inputVariables.map { linkInitValue($0) }.joined(separator: ", ")
        let computedVariables = classDecl.computedVariables
        let funcDecl = try FunctionDeclSyntax("\(raw: classDecl.privacyModifier) func snapshot(includeLinks: Bool = false) -> Snapshot") {
            if computedVariables.isEmpty {
                "if includeLinks { return Snapshot(\(raw: initLinksArgs)) }"
                "else { return Snapshot(\(raw: initArgs)) }"
            } else {
                "var result = includeLinks ? Snapshot(\(raw: initLinksArgs)) : Snapshot(\(raw: initArgs))"
                for varDecl in computedVariables {
                    "result.\(raw: varDecl.identifier) = \(raw: varDecl.identifier)"
                }
                "return result"
            }
        }

        return DeclSyntax(funcDecl)
    }

    static func createBackgroundChangesMonitorSyntax(with classDecl: ClassDeclSyntax) throws -> [DeclSyntax] {
        guard classDecl.attributes.contains(named: "Model") else { return [] }

        let className = classDecl.name.text
        let variables = classDecl.inputVariables
        let privacyModifier = classDecl.privacyModifier

        let classDecl = try ClassDeclSyntax("@MainActor private final class BackgroundChangesMonitor") {
            "private var monitorChangesTask: Task<(), Never>?"
            "weak var object: \(raw: className)?"

            try InitializerDeclSyntax("init(object: \(raw: className))") {
                "self.object = object"
                "let id = object.persistentModelID"
                """
                monitorChangesTask = Task.detached { [weak monitor = self] in
                    for await userInfo in NotificationCenter.default.notifications(named: ModelContext.didSave).compactMap({ $0.userInfo }) {
                        let updates = userInfo[ModelContext.NotificationKey.updatedIdentifiers.rawValue] as? [PersistentIdentifier]
                        if updates?.contains(where: { $0 == id }) == true {
                            await monitor?.notify()
                        }
                    }
                }
                """
            }

            try DeinitializerDeclSyntax("deinit") {
                "monitorChangesTask?.cancel()"
            }

            try FunctionDeclSyntax("func notify()") {
                "guard let object else { return }"
                for varDecl in variables where !varDecl.isUnique {
                    "object._$observationRegistrar.withMutation(of: object, keyPath: \\.\(raw: varDecl.identifier)) {}"
                }
            }
        }

        let varDecl = DeclSyntax(stringLiteral: "@Transient @MainActor private var __monitor: BackgroundChangesMonitor?")

        let startFuncDecl = try FunctionDeclSyntax("@MainActor \(raw: privacyModifier) func startMonitorBackgroundChanges()") {
            "guard __monitor == nil else { return }"
            "__monitor = BackgroundChangesMonitor(object: self)"
        }

        let stopFuncDecl = try FunctionDeclSyntax("@MainActor \(raw: privacyModifier) func stopMonitorBackgroundChanges()") {
            "__monitor = nil"
        }

        return [
            DeclSyntax(classDecl),
            DeclSyntax(varDecl),
            DeclSyntax(startFuncDecl),
            DeclSyntax(stopFuncDecl),
        ]
    }
}
