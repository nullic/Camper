import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CamperMacros

final class IOModelMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "IOModel": IOModel.self,
        "Virtual": IOAttribute.self,
        "NonLinkable": IOAttribute.self,
        "Ignorable": IOAttribute.self,
    ]

    func testIOModelAppliedToNonClass() {
        assertMacroExpansion(
            """
            @IOModel
            struct NotAClass {
                var name: String
            }
            """,
            expandedSource: """
            struct NotAClass {
                var name: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@IOModel can only be applied to class", line: 1, column: 1),
                DiagnosticSpec(message: "@IOModel can only be applied to class", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    func testIOModelSimpleClass() {
        assertMacroExpansion(
            """
            @IOModel
            class User {
                var name: String
                var age: Int
            }
            """,
            expandedSource: """
            class User {
                var name: String
                var age: Int

                internal protocol InputModel: Sendable {
                    var name: String {
                        get
                    }
                    var age: Int {
                        get
                    }
                }

                internal init(input: User.InputModel, context: ModelContext) throws {
                    self.name = input.name
                    self.age = input.age
                }

                internal func update(input: User.InputModel) throws {
                    self.name = input.name
                    self.age = input.age
                }

                internal struct Snapshot: User.InputModel, Codable, @unchecked Sendable {
                    internal var name: String
                    internal var age: Int
                    internal init(name: String, age: Int) {
                        self.name = name
                        self.age = age
                    }
                    internal init(_ input: User.InputModel) {
                        self.name = input.name
                        self.age = input.age
                    }
                    private enum CodingKeys: CodingKey {
                        case name
                        case age
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(name, forKey: .name)
                        try container.encode(age, forKey: .age)
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.name = try values.decode(String.self, forKey: .name)
                        self.age = try values.decode(Int.self, forKey: .age)
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(name: name, age: age)
                    }else { return Snapshot(name: name, age: age) }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testVirtualAttributeIsNoOp() {
        assertMacroExpansion(
            """
            @Virtual
            var computed: String
            """,
            expandedSource: """
            var computed: String
            """,
            macros: testMacros
        )
    }

    func testIOModelWithIgnorableProperty() {
        assertMacroExpansion(
            """
            @IOModel
            class User {
                var name: String
                @Ignorable var nickname: String
            }
            """,
            expandedSource: """
            class User {
                var name: String
                var nickname: String

                internal enum NicknameInput: Codable {
                    case ignore
                    case value(_ value: String)
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.singleValueContainer()
                        switch self {
                        case .ignore:
                            break
                        case .value(let value):
                            try container.encode(value)
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.singleValueContainer()
                        let value = try values.decode(String.self)
                        self = .value(value)
                    }
                }

                internal protocol InputModel: Sendable {
                    var name: String {
                        get
                    }
                    var nickname: User.NicknameInput {
                        get
                    }
                }

                internal init(input: User.InputModel, context: ModelContext) throws {
                    self.name = input.name
                    switch input.nickname {
                    case .ignore:
                        break
                    case .value(let value):
                        self.nickname = value
                    }
                }

                internal func update(input: User.InputModel) throws {
                    self.name = input.name
                    switch input.nickname {
                    case .ignore:
                        break
                    case .value(let value):
                        self.nickname = value
                    }
                }

                internal struct Snapshot: User.InputModel, Codable, @unchecked Sendable {
                    internal var name: String
                    internal var nickname: User.NicknameInput = .ignore
                    internal init(name: String, nickname: User.NicknameInput = .ignore) {
                        self.name = name
                        self.nickname = nickname
                    }
                    internal init(_ input: User.InputModel) {
                        self.name = input.name
                        self.nickname = input.nickname
                    }
                    private enum CodingKeys: CodingKey {
                        case name
                        case nickname
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(name, forKey: .name)
                        switch nickname {
                        case .ignore:
                            break
                        default:
                            try container.encode(nickname, forKey: .nickname)
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.name = try values.decode(String.self, forKey: .name)
                        self.nickname = try values.decodeIfPresent(User.NicknameInput.self, forKey: .nickname) ?? .ignore
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(name: name, nickname: .value(nickname))
                    }else { return Snapshot(name: name, nickname: .value(nickname)) }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelWithIgnorablePropertyDefaultValue() {
        assertMacroExpansion(
            """
            @IOModel
            class User {
                var name: String
                @Ignorable var nickname: String = "Anonymous"
            }
            """,
            expandedSource: """
            class User {
                var name: String
                var nickname: String = "Anonymous"

                internal enum NicknameInput: Codable {
                    case ignore
                    case value(_ value: String)
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.singleValueContainer()
                        switch self {
                        case .ignore:
                            break
                        case .value(let value):
                            try container.encode(value)
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.singleValueContainer()
                        let value = try values.decode(String.self)
                        self = .value(value)
                    }
                }

                internal protocol InputModel: Sendable {
                    var name: String {
                        get
                    }
                    var nickname: User.NicknameInput {
                        get
                    }
                }

                internal init(input: User.InputModel, context: ModelContext) throws {
                    self.name = input.name
                    switch input.nickname {
                    case .ignore:
                        self.nickname = "Anonymous"
                    case .value(let value):
                        self.nickname = value
                    }
                }

                internal func update(input: User.InputModel) throws {
                    self.name = input.name
                    switch input.nickname {
                    case .ignore:
                        break
                    case .value(let value):
                        self.nickname = value
                    }
                }

                internal struct Snapshot: User.InputModel, Codable, @unchecked Sendable {
                    internal var name: String
                    internal var nickname: User.NicknameInput = .ignore
                    internal init(name: String, nickname: User.NicknameInput = .ignore) {
                        self.name = name
                        self.nickname = nickname
                    }
                    internal init(_ input: User.InputModel) {
                        self.name = input.name
                        self.nickname = input.nickname
                    }
                    private enum CodingKeys: CodingKey {
                        case name
                        case nickname
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(name, forKey: .name)
                        switch nickname {
                        case .ignore:
                            break
                        default:
                            try container.encode(nickname, forKey: .nickname)
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.name = try values.decode(String.self, forKey: .name)
                        self.nickname = try values.decodeIfPresent(User.NicknameInput.self, forKey: .nickname) ?? .ignore
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(name: name, nickname: .value(nickname))
                    }else { return Snapshot(name: name, nickname: .value(nickname)) }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelWithRelationship() {
        assertMacroExpansion(
            """
            @IOModel
            class Article {
                var title: String
                @Relationship var author: Author
            }
            """,
            expandedSource: """
            class Article {
                var title: String
                @Relationship var author: Author

                internal enum AuthorInput: Codable {
                    case ignore
                    case value(_ value: Author)
                    case input(_ value: Author.InputModel)
                    case link(_ value: Author.UniqueID)
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.singleValueContainer()
                        switch self {
                        case .ignore:
                            break
                        case .link(let value):
                            try container.encode(value)
                        case .input(let value):
                            try container.encode(Author.Snapshot(value))
                        case .value(let value):
                            try container.encode(value.snapshot())
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.singleValueContainer()
                        do {
                            let value = try values.decode(Author.Snapshot.self)
                            self = .input(value)
                        } catch {
                            let value = try values.decode(Author.UniqueID.self)
                            self = .link(value)
                        }
                    }
                }

                internal protocol InputModel: Sendable {
                    var title: String {
                        get
                    }
                    var author: Article.AuthorInput {
                        get
                    }
                }

                internal init(input: Article.InputModel, context: ModelContext) throws {
                    self.title = input.title
                    switch input.author {
                    case .ignore:
                        break
                    case .value(let value):
                        self.author = value
                    case .link(let value):
                        self.author = try Author.unique(value, in: context)
                    case .input(let value):
                        self.author = try Author.insert(value, in: context)
                    }
                }

                internal func update(input: Article.InputModel) throws {
                    self.title = input.title
                    switch input.author {
                    case .ignore:
                        break
                    case .value(let value):
                        self.author = value
                    case .link(let value):
                        self.author = try Author.unique(value, in: context)
                    case .input(let value):
                        self.author = try Author.insert(value, in: context)
                    }
                }

                internal struct Snapshot: Article.InputModel, Codable, @unchecked Sendable {
                    internal var title: String
                    internal var author: Article.AuthorInput = .ignore
                    internal init(title: String, author: Article.AuthorInput = .ignore) {
                        self.title = title
                        self.author = author
                    }
                    internal init(_ input: Article.InputModel) {
                        self.title = input.title
                        self.author = input.author
                    }
                    private enum CodingKeys: CodingKey {
                        case title
                        case author
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(title, forKey: .title)
                        switch author {
                        case .ignore:
                            break
                        default:
                            try container.encode(author, forKey: .author)
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.title = try values.decode(String.self, forKey: .title)
                        self.author = try values.decodeIfPresent(Article.AuthorInput.self, forKey: .author) ?? .ignore
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(title: title, author: .link(author.uniqueValue))
                    }else { return Snapshot(title: title, author: .ignore) }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelWithOptionalProperty() {
        assertMacroExpansion(
            """
            @IOModel
            class Profile {
                var name: String
                var bio: String?
            }
            """,
            expandedSource: """
            class Profile {
                var name: String
                var bio: String?

                internal protocol InputModel: Sendable {
                    var name: String {
                        get
                    }
                    var bio: String? {
                        get
                    }
                }

                internal init(input: Profile.InputModel, context: ModelContext) throws {
                    self.name = input.name
                    self.bio = input.bio
                }

                internal func update(input: Profile.InputModel) throws {
                    self.name = input.name
                    self.bio = input.bio
                }

                internal struct Snapshot: Profile.InputModel, Codable, @unchecked Sendable {
                    internal var name: String
                    internal var bio: String?
                    internal init(name: String, bio: String? = nil) {
                        self.name = name
                        self.bio = bio
                    }
                    internal init(_ input: Profile.InputModel) {
                        self.name = input.name
                        self.bio = input.bio
                    }
                    private enum CodingKeys: CodingKey {
                        case name
                        case bio
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(name, forKey: .name)
                        try container.encode(bio, forKey: .bio)
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.name = try values.decode(String.self, forKey: .name)
                        self.bio = try values.decodeIfPresent(String.self, forKey: .bio)
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(name: name, bio: bio)
                    }else { return Snapshot(name: name, bio: bio) }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelWithLetConstant() {
        assertMacroExpansion(
            """
            @IOModel
            class Item {
                let id: UUID
                var name: String
            }
            """,
            expandedSource: """
            class Item {
                let id: UUID
                var name: String

                internal protocol InputModel: Sendable {
                    var id: UUID {
                        get
                    }
                    var name: String {
                        get
                    }
                }

                internal init(input: Item.InputModel, context: ModelContext) throws {
                    self.id = input.id
                    self.name = input.name
                }

                internal func update(input: Item.InputModel) throws {
                    self.name = input.name
                }

                internal struct Snapshot: Item.InputModel, Codable, @unchecked Sendable {
                    internal var id: UUID
                    internal var name: String
                    internal init(id: UUID, name: String) {
                        self.id = id
                        self.name = name
                    }
                    internal init(_ input: Item.InputModel) {
                        self.id = input.id
                        self.name = input.name
                    }
                    private enum CodingKeys: CodingKey {
                        case id
                        case name
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(id, forKey: .id)
                        try container.encode(name, forKey: .name)
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.id = try values.decode(UUID.self, forKey: .id)
                        self.name = try values.decode(String.self, forKey: .name)
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(id: id, name: name)
                    }else { return Snapshot(id: id, name: name) }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelWithUniqueModel() {
        assertMacroExpansion(
            """
            @Model @IOModel
            class Item {
                @Attribute(.unique) var id: UUID
                var name: String
            }
            """,
            expandedSource: """
            @Model
            class Item {
                @Attribute(.unique) var id: UUID
                var name: String

                internal protocol InputModel: Sendable {
                    var id: UUID {
                        get
                    }
                    var name: String {
                        get
                    }
                }

                internal init(input: Item.InputModel, context: ModelContext) throws {
                    self.id = input.id
                    self.name = input.name
                }

                internal func update(input: Item.InputModel) throws {
                    self.name = input.name
                }

                internal struct Snapshot: Item.InputModel, Codable, @unchecked Sendable {
                    internal var id: UUID
                    internal var name: String
                    internal init(id: UUID, name: String) {
                        self.id = id
                        self.name = name
                    }
                    internal init(_ input: Item.InputModel) {
                        self.id = input.id
                        self.name = input.name
                    }
                    private enum CodingKeys: CodingKey {
                        case id
                        case name
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(id, forKey: .id)
                        try container.encode(name, forKey: .name)
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.id = try values.decode(UUID.self, forKey: .id)
                        self.name = try values.decode(String.self, forKey: .name)
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(id: id, name: name)
                    }else { return Snapshot(id: id, name: name) }
                }

                @MainActor private final class BackgroundChangesMonitor {
                    private var monitorChangesTask: Task<(), Never>?
                    weak var object: Item?
                    init(object: Item) {
                        self.object = object
                        let id = object.persistentModelID
                        monitorChangesTask = Task.detached { [weak monitor = self] in
                            for await userInfo in NotificationCenter.default.notifications(named: ModelContext.didSave).compactMap({ $0.userInfo
                                }) {
                                let updates = userInfo[ModelContext.NotificationKey.updatedIdentifiers.rawValue] as? [PersistentIdentifier]
                                if updates?.contains(where: { $0 == id
                                    }) == true {
                                    await monitor?.notify()
                                }
                            }
                        }
                    }
                    deinit {
                        monitorChangesTask?.cancel()
                    }
                    func notify() {
                        guard let object else {
                            return
                        }
                        object._$observationRegistrar.withMutation(of: object, keyPath: \\.name) {
                        }
                    }
                }

                @Transient @MainActor private var __monitor: BackgroundChangesMonitor?

                @MainActor internal func startMonitorBackgroundChanges() {
                    guard __monitor == nil else {
                        return
                    }
                    __monitor = BackgroundChangesMonitor(object: self)
                }

                @MainActor internal func stopMonitorBackgroundChanges() {
                    __monitor = nil
                }
            }

            extension Item: UniqueFindable {
                internal typealias UniqueID = UUID

                @_implements(UniqueFindable, uniqueValue)
                internal var _uniqueValueId: UniqueID { id }

                internal class func unique(_ value: UUID, in context: ModelContext) throws -> Item? {
                    var descriptor = FetchDescriptor<Item>(predicate: #Predicate {
                            $0.id == value
                        })
                    descriptor.fetchLimit = 1
                    return try context.fetch(descriptor).first
                }
                internal class func unique(_ values: [UUID], in context: ModelContext) throws -> [Item] {
                    try values.compactMap {
                        try unique($0, in: context)
                    }
                }
                @discardableResult internal class func delete(_ value: UUID, in context: ModelContext) throws -> Item? {
                    let model = try unique(value, in: context)
                    if let model {
                        context.delete(model)
                    }
                    return model
                }
                @discardableResult internal class func delete(_ values: [UUID], in context: ModelContext) throws -> [Item] {
                    try values.compactMap {
                        try delete($0, in: context)
                    }
                }
                @discardableResult internal class func insert(_ input: Item.InputModel, in context: ModelContext) throws -> Item {
                    let result: Item
                    if let exist = try unique(input.id, in: context) {
                        result = exist
                        result.name = input.name
                    } else {
                        result = try Item(input: input, context: context)
                        context.insert(result)
                    }
                    return result
                }
                @discardableResult internal class func insert(_ inputs: [Item.InputModel], in context: ModelContext) throws -> [Item] {
                    try inputs.map {
                        try insert($0, in: context)
                    }
                }
                @discardableResult internal class func replace(_ inputs: [Item.InputModel], in context: ModelContext) throws -> [Item] {
                    let inserted = try inputs.map {
                        try insert($0, in: context)
                    }
                    let insertedIDs = inputs.map {
                        $0.id
                    }
                    let descriptor = FetchDescriptor<Item>(predicate: #Predicate {
                            !insertedIDs.contains($0.id)
                        })
                    for item in try context.fetch(descriptor) {
                        context.delete(item)
                    }
                    return inserted
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelReplaceMethodNotGeneratedWithoutUniqueProperty() {
        assertMacroExpansion(
            """
            @IOModel
            class Item {
                var name: String
            }
            """,
            expandedSource: """
            class Item {
                var name: String

                internal protocol InputModel: Sendable {
                    var name: String {
                        get
                    }
                }

                internal init(input: Item.InputModel, context: ModelContext) throws {
                    self.name = input.name
                }

                internal func update(input: Item.InputModel) throws {
                    self.name = input.name
                }

                internal struct Snapshot: Item.InputModel, Codable, @unchecked Sendable {
                    internal var name: String
                    internal init(name: String) {
                        self.name = name
                    }
                    internal init(_ input: Item.InputModel) {
                        self.name = input.name
                    }
                    private enum CodingKeys: CodingKey {
                        case name
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(name, forKey: .name)
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.name = try values.decode(String.self, forKey: .name)
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(name: name)
                    }else { return Snapshot(name: name) }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelWithComputedProperty() {
        assertMacroExpansion(
            """
            @IOModel
            class Product {
                var name: String
                var price: Double { 9.99 }
            }
            """,
            expandedSource: """
            class Product {
                var name: String
                var price: Double { 9.99 }

                internal protocol InputModel: Sendable {
                    var name: String {
                        get
                    }
                }

                internal init(input: Product.InputModel, context: ModelContext) throws {
                    self.name = input.name
                }

                internal func update(input: Product.InputModel) throws {
                    self.name = input.name
                }

                internal struct Snapshot: Product.InputModel, Codable, @unchecked Sendable {
                    internal var name: String
                    internal var price: Double? = nil
                    internal init(name: String) {
                        self.name = name
                    }
                    internal init(_ input: Product.InputModel) {
                        self.name = input.name
                    }
                    private enum CodingKeys: CodingKey {
                        case name
                        case price
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(name, forKey: .name)
                        try container.encodeIfPresent(price, forKey: .price)
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.name = try values.decode(String.self, forKey: .name)
                        self.price = try values.decodeIfPresent(Double.self, forKey: .price)
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    var result = includeLinks ? Snapshot(name: name) : Snapshot(name: name)
                    result.price = price
                    return result
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelWithOptionalComputedProperty() {
        assertMacroExpansion(
            """
            @IOModel
            class Entity {
                var name: String
                var organizationId: String? { nil }
            }
            """,
            expandedSource: """
            class Entity {
                var name: String
                var organizationId: String? { nil }

                internal protocol InputModel: Sendable {
                    var name: String {
                        get
                    }
                }

                internal init(input: Entity.InputModel, context: ModelContext) throws {
                    self.name = input.name
                }

                internal func update(input: Entity.InputModel) throws {
                    self.name = input.name
                }

                internal struct Snapshot: Entity.InputModel, Codable, @unchecked Sendable {
                    internal var name: String
                    internal var organizationId: String? = nil
                    internal init(name: String) {
                        self.name = name
                    }
                    internal init(_ input: Entity.InputModel) {
                        self.name = input.name
                    }
                    private enum CodingKeys: CodingKey {
                        case name
                        case organizationId
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(name, forKey: .name)
                        try container.encodeIfPresent(organizationId, forKey: .organizationId)
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.name = try values.decode(String.self, forKey: .name)
                        self.organizationId = try values.decodeIfPresent(String.self, forKey: .organizationId)
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    var result = includeLinks ? Snapshot(name: name) : Snapshot(name: name)
                    result.organizationId = organizationId
                    return result
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelWithMultipleComputedProperties() {
        assertMacroExpansion(
            """
            @IOModel
            class Article {
                var title: String
                var wordCount: Int { 42 }
                var slug: String { title }
            }
            """,
            expandedSource: """
            class Article {
                var title: String
                var wordCount: Int { 42 }
                var slug: String { title }

                internal protocol InputModel: Sendable {
                    var title: String {
                        get
                    }
                }

                internal init(input: Article.InputModel, context: ModelContext) throws {
                    self.title = input.title
                }

                internal func update(input: Article.InputModel) throws {
                    self.title = input.title
                }

                internal struct Snapshot: Article.InputModel, Codable, @unchecked Sendable {
                    internal var title: String
                    internal var wordCount: Int? = nil
                    internal var slug: String? = nil
                    internal init(title: String) {
                        self.title = title
                    }
                    internal init(_ input: Article.InputModel) {
                        self.title = input.title
                    }
                    private enum CodingKeys: CodingKey {
                        case title
                        case wordCount
                        case slug
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(title, forKey: .title)
                        try container.encodeIfPresent(wordCount, forKey: .wordCount)
                        try container.encodeIfPresent(slug, forKey: .slug)
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.title = try values.decode(String.self, forKey: .title)
                        self.wordCount = try values.decodeIfPresent(Int.self, forKey: .wordCount)
                        self.slug = try values.decodeIfPresent(String.self, forKey: .slug)
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    var result = includeLinks ? Snapshot(title: title) : Snapshot(title: title)
                    result.wordCount = wordCount
                    result.slug = slug
                    return result
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIgnorableAttributeIsNoOp() {
        assertMacroExpansion(
            """
            @Ignorable
            var nickname: String
            """,
            expandedSource: """
            var nickname: String
            """,
            macros: testMacros
        )
    }

    func testIOModelWithNonLinkableOptionalRelationship() {
        assertMacroExpansion(
            """
            @IOModel
            class Article {
                var title: String
                @NonLinkable @Relationship var detail: Detail?
            }
            """,
            expandedSource: """
            class Article {
                var title: String
                @Relationship var detail: Detail?

                internal enum DetailInput: Codable {
                    case ignore
                    case value(_ value: Detail?)
                    case input(_ value: Detail.InputModel)
                    case update(_ value: Detail.InputModel)
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.singleValueContainer()
                        switch self {
                        case .ignore:
                            break
                        case .input(let value):
                            try container.encode(Detail.Snapshot(value))
                        case .update(let value):
                            try container.encode(Detail.Snapshot(value))
                        case .value(let value):
                            try container.encode(value?.snapshot())
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.singleValueContainer()
                        do {
                            let value = try values.decode(Detail.Snapshot.self)
                            self = .input(value)
                        }
                    }
                }

                internal protocol InputModel: Sendable {
                    var title: String {
                        get
                    }
                    var detail: Article.DetailInput {
                        get
                    }
                }

                internal init(input: Article.InputModel, context: ModelContext) throws {
                    self.title = input.title
                    switch input.detail {
                    case .ignore:
                        break
                    case .value(let value):
                        self.detail = value
                    case .input(let value):
                        self.detail = try Detail.insert(value, in: context)
                    case .update(let value):
                        self.detail = try Detail.insert(value, in: context)
                    }
                }

                internal func update(input: Article.InputModel) throws {
                    self.title = input.title
                    switch input.detail {
                    case .ignore:
                        break
                    case .value(let value):
                        self.detail = value
                    case .input(let value):
                        if let old = self.detail {
                            context.delete(old)
                        }
                        self.detail = try Detail.insert(value, in: context)
                    case .update(let value):
                        if let existing = self.detail {
                            try existing.update(input: value)
                        }
                        else {
                            let new = try Detail(input: value, context: context);
                            context.insert(new);
                            self.detail = new
                        }
                    }
                }

                internal struct Snapshot: Article.InputModel, Codable, @unchecked Sendable {
                    internal var title: String
                    internal var detail: Article.DetailInput = .ignore
                    internal init(title: String, detail: Article.DetailInput = .ignore) {
                        self.title = title
                        self.detail = detail
                    }
                    internal init(_ input: Article.InputModel) {
                        self.title = input.title
                        self.detail = input.detail
                    }
                    private enum CodingKeys: CodingKey {
                        case title
                        case detail
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(title, forKey: .title)
                        switch detail {
                        case .ignore:
                            break
                        default:
                            try container.encode(detail, forKey: .detail)
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.title = try values.decode(String.self, forKey: .title)
                        self.detail = try values.decodeIfPresent(Article.DetailInput.self, forKey: .detail) ?? .ignore
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(title: title, detail: .ignore)
                    }else { return Snapshot(title: title, detail: .ignore) }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testIOModelWithNonLinkableArrayRelationship() {
        assertMacroExpansion(
            """
            @IOModel
            class Article {
                var title: String
                @NonLinkable @Relationship var tags: [Tag]
            }
            """,
            expandedSource: """
            class Article {
                var title: String
                @Relationship var tags: [Tag]

                internal enum TagsInput: Codable {
                    case ignore
                    case value(_ value: [Tag])
                    case input(_ value: [Tag.InputModel])
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.singleValueContainer()
                        switch self {
                        case .ignore:
                            break
                        case .input(let value):
                            try container.encode(value.map {
                                    Tag.Snapshot($0)
                                })
                        case .value(let value):
                            try container.encode(value.map {
                                    $0.snapshot()
                                })
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.singleValueContainer()
                        do {
                            let value = try values.decode([Tag.Snapshot].self)
                            self = .input(value)
                        }
                    }
                }

                internal protocol InputModel: Sendable {
                    var title: String {
                        get
                    }
                    var tags: Article.TagsInput {
                        get
                    }
                }

                internal init(input: Article.InputModel, context: ModelContext) throws {
                    self.title = input.title
                    switch input.tags {
                    case .ignore:
                        break
                    case .value(let value):
                        self.tags = value
                    case .input(let value):
                        self.tags = try Tag.insert(value, in: context)
                    }
                }

                internal func update(input: Article.InputModel) throws {
                    self.title = input.title
                    switch input.tags {
                    case .ignore:
                        break
                    case .value(let value):
                        self.tags = value
                    case .input(let value):
                        self.tags.forEach {
                            context.delete($0)
                        }
                        self.tags = try Tag.insert(value, in: context)
                    }
                }

                internal struct Snapshot: Article.InputModel, Codable, @unchecked Sendable {
                    internal var title: String
                    internal var tags: Article.TagsInput = .ignore
                    internal init(title: String, tags: Article.TagsInput = .ignore) {
                        self.title = title
                        self.tags = tags
                    }
                    internal init(_ input: Article.InputModel) {
                        self.title = input.title
                        self.tags = input.tags
                    }
                    private enum CodingKeys: CodingKey {
                        case title
                        case tags
                    }
                    internal func encode(to encoder: any Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(title, forKey: .title)
                        switch tags {
                        case .ignore:
                            break
                        default:
                            try container.encode(tags, forKey: .tags)
                        }
                    }
                    internal init(from decoder: any Decoder) throws {
                        let values = try decoder.container(keyedBy: CodingKeys.self)
                        self.title = try values.decode(String.self, forKey: .title)
                        self.tags = try values.decodeIfPresent(Article.TagsInput.self, forKey: .tags) ?? .ignore
                    }
                }

                internal func snapshot(includeLinks: Bool = false) -> Snapshot {
                    if includeLinks {
                        return Snapshot(title: title, tags: .ignore)
                    }else { return Snapshot(title: title, tags: .ignore) }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testNonLinkableAttributeIsNoOp() {
        assertMacroExpansion(
            """
            @NonLinkable
            var relation: Model
            """,
            expandedSource: """
            var relation: Model
            """,
            macros: testMacros
        )
    }
}
