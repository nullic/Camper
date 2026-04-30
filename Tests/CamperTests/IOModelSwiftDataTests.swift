import Foundation
import SwiftData
import XCTest

@testable import Camper

// MARK: - Models

@IOModel
@Model
final class Tag {
    @Attribute(.unique)
    var id: UUID

    var label: String

    init(id: UUID, label: String) {
        self.id = id
        self.label = label
    }
}

@IOModel
@Model
final class Article {
    @Attribute(.unique)
    var id: UUID

    var title: String
    var body: String

    @Ignorable
    var draft: Bool = false

    @Relationship(deleteRule: .cascade)
    var tags: [Tag]?

    init(id: UUID, title: String, body: String, tags: [Tag]? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
    }
}

// MARK: - Tests

final class IOModelSwiftDataTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Article.self, Tag.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: Snapshot

    func testSnapshotRoundTripsCodableProperties() throws {
        let context = try makeContext()
        let article = Article(id: UUID(), title: "Hello", body: "World")
        context.insert(article)
        try context.save()

        let snapshot = article.snapshot()

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(Article.Snapshot.self, from: data)

        XCTAssertEqual(decoded.title, "Hello")
        XCTAssertEqual(decoded.body, "World")
        XCTAssertEqual(decoded.id, article.id)
    }

    // MARK: unique / insert / delete

    func testUniqueLookupFindsInsertedModel() throws {
        let context = try makeContext()
        let id = UUID()
        let article = Article(id: id, title: "T", body: "B")
        context.insert(article)
        try context.save()

        let found = try Article.unique(id, in: context)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "T")

        let missing = try Article.unique(UUID(), in: context)
        XCTAssertNil(missing)
    }

    func testUniqueArrayLookupFindsAllInserted() throws {
        let context = try makeContext()
        let ids = [UUID(), UUID(), UUID()]
        for id in ids {
            context.insert(Article(id: id, title: "T-\(id.uuidString.prefix(4))", body: "B"))
        }
        try context.save()

        let found = try Article.unique(ids, in: context)
        XCTAssertEqual(found.count, 3)
        XCTAssertEqual(Set(found.map { $0.id }), Set(ids))
    }

    func testInsertViaSnapshotCreatesNewRecord() throws {
        let context = try makeContext()
        let id = UUID()
        let snapshot = Article.Snapshot(id: id, title: "Inserted", body: "Body")
        let inserted = try Article.insert(snapshot, in: context)
        try context.save()

        XCTAssertEqual(inserted.id, id)
        XCTAssertEqual(inserted.title, "Inserted")

        let found = try Article.unique(id, in: context)
        XCTAssertNotNil(found)
    }

    func testInsertViaSnapshotUpdatesExistingRecordWithSameUniqueID() throws {
        let context = try makeContext()
        let id = UUID()
        let original = Article(id: id, title: "Original", body: "B")
        context.insert(original)
        try context.save()

        let snapshot = Article.Snapshot(id: id, title: "Updated", body: "B")
        let result = try Article.insert(snapshot, in: context)
        try context.save()

        XCTAssertEqual(result.title, "Updated")

        // Only one record with this id should exist.
        let all = try context.fetch(FetchDescriptor<Article>())
        XCTAssertEqual(all.filter { $0.id == id }.count, 1)
    }

    func testDeleteByUniqueIDRemovesRecord() throws {
        let context = try makeContext()
        let id = UUID()
        context.insert(Article(id: id, title: "T", body: "B"))
        try context.save()

        let deleted = try Article.delete(id, in: context)
        try context.save()
        XCTAssertNotNil(deleted)

        let found = try Article.unique(id, in: context)
        XCTAssertNil(found)
    }

    // MARK: update via InputModel

    func testUpdateAppliesNonRelationshipFields() throws {
        let context = try makeContext()
        let id = UUID()
        let article = Article(id: id, title: "Old", body: "Old body")
        context.insert(article)
        try context.save()

        var input = Article.Snapshot(id: id, title: "New title", body: "New body")
        input.draft = .value(true)
        try article.update(input: input)
        try context.save()

        let reloaded = try Article.unique(id, in: context)
        XCTAssertEqual(reloaded?.title, "New title")
        XCTAssertEqual(reloaded?.body, "New body")
        XCTAssertEqual(reloaded?.draft, true)
    }

    func testIgnorableFieldDefaultsToIgnoreInSnapshot() throws {
        let context = try makeContext()
        let id = UUID()
        let snapshot = Article.Snapshot(id: id, title: "T", body: "B")
        // draft was not set — should default to .ignore, leaving the model's declared default.
        let inserted = try Article.insert(snapshot, in: context)
        try context.save()

        XCTAssertEqual(inserted.draft, false, "@Ignorable default value must be preserved when snapshot says .ignore")
    }

    // MARK: Relationships

    func testRelationshipLinkResolvesByUniqueID() throws {
        let context = try makeContext()
        let tagID = UUID()
        let tag = Tag(id: tagID, label: "swift")
        context.insert(tag)
        try context.save()

        var snapshot = Article.Snapshot(id: UUID(), title: "Article", body: "...")
        snapshot.tags = .link([tagID])
        let article = try Article.insert(snapshot, in: context)
        try context.save()

        XCTAssertEqual(article.tags?.count, 1)
        XCTAssertEqual(article.tags?.first?.id, tagID)
    }

    func testRelationshipInputCreatesNestedRecord() throws {
        let context = try makeContext()
        let tagID = UUID()

        var snapshot = Article.Snapshot(id: UUID(), title: "Article", body: "...")
        snapshot.tags = .input([Tag.Snapshot(id: tagID, label: "macos")])
        let article = try Article.insert(snapshot, in: context)
        try context.save()

        XCTAssertEqual(article.tags?.count, 1)
        XCTAssertEqual(article.tags?.first?.label, "macos")

        let tag = try Tag.unique(tagID, in: context)
        XCTAssertNotNil(tag, "nested input must materialise the related record")
    }
}
