import Camper
import OSLog
import SwiftData

@IOModel
public final class NonModelModel {
    let uuid: UUID
    init(uuid: UUID) { self.uuid = uuid }
}

@IOModel
@Model
public final class OtherModel {
    @Attribute(.unique)
    private(set) var uuid: UUID
    private(set) var value: UUID?

    init(uuid: UUID) { self.uuid = uuid }
}

@IOModel
@Model
public final class SomeModel {
    @Attribute(.unique)
    public private(set) var id: UUID

    @NonLinkable
    @Relationship
    private var relModel: [OtherModel]?

    @Relationship
    private var relModelSingle: OtherModel!

    @Ignorable
    private(set) var nickname: String = "Anonymous"

    private(set) var trst2: String = "ret" { didSet { trst2 = trst2 } }
    var trst: String { "ret" }

    init(id: UUID) { self.id = id }
}

// MARK: - Usage examples

func uniqueExample(context: ModelContext) throws {
    let id = UUID()

    // Find a single model by unique ID
    let model = try SomeModel.unique(id, in: context)

    // Find multiple models by unique IDs
    let models = try SomeModel.unique([id], in: context)

    _ = (model, models)
}

func deleteExample(context: ModelContext) throws {
    let id = UUID()

    // Delete a single model by unique ID
    let deleted = try SomeModel.delete(id, in: context)

    // Delete multiple models by unique IDs
    let deletedAll = try SomeModel.delete([id], in: context)

    _ = (deleted, deletedAll)
}

func insertExample(context: ModelContext) throws {
    // Insert using a Snapshot (conforms to InputModel).
    // If a model with the same unique ID exists, it is updated; otherwise a new one is created.
    let snapshot = SomeModel.Snapshot(id: UUID())
    let model = try SomeModel.insert(snapshot, in: context)

    // Insert multiple at once
    let models = try SomeModel.insert([snapshot], in: context)

    _ = (model, models)
}

func ignorableExample(context: ModelContext) throws {
    // @Ignorable properties default to .ignore in Snapshot.
    // When .ignore, init uses the declared default ("Anonymous").
    var snapshot = SomeModel.Snapshot(id: UUID())
    let model1 = try SomeModel.insert(snapshot, in: context)

    // Provide a value explicitly with .value
    snapshot.nickname = .value("Trail Runner")
    let model2 = try SomeModel.insert(snapshot, in: context)

    _ = (model1, model2)
}
