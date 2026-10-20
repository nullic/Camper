import Foundation
import XCTest

@testable import Camper

final class LogFileWriterTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("camper-writer-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    private func logFiles() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "log" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func lines() throws -> [String] {
        try logFiles().flatMap { try String(contentsOf: $0, encoding: .utf8).split(separator: "\n").map(String.init) }
    }

    func testNothingIsCreatedUntilTheFirstLine() {
        let writer = LogFileWriter(folder: folder)
        writer.flush()

        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testALineCarriesDateLevelAndMessage() throws {
        let writer = LogFileWriter(folder: folder)
        writer.append(level: "ERROR", "[Net][a.swift:1 -- f()]: boom")
        writer.flush()

        let line = try XCTUnwrap(lines().first)
        XCTAssertNotNil(line.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2} ERROR \[Net\]\[a\.swift:1 -- f\(\)\]: boom$"#, options: .regularExpression), line)
    }

    func testLinesKeepTheOrderTheyWereHandedOver() throws {
        let writer = LogFileWriter(folder: folder)
        for i in 0 ..< 200 { writer.append(level: "INFO", "n\(i)") }
        writer.flush()

        XCTAssertEqual(try lines().map { String($0.split(separator: " ").last!) }, (0 ..< 200).map { "n\($0)" })
    }

    func testConcurrentWritersLoseNoLineAndTearNone() throws {
        let writer = LogFileWriter(folder: folder)
        let group = DispatchGroup()
        for thread in 0 ..< 8 {
            group.enter()
            DispatchQueue.global().async {
                for i in 0 ..< 500 { writer.append(level: "INFO", "t\(thread)-\(i)-end") }
                group.leave()
            }
        }
        group.wait()
        writer.flush()

        let all = try lines()
        XCTAssertEqual(all.count, 4000)
        XCTAssertTrue(all.allSatisfy { $0.hasSuffix("-end") && $0.contains(" INFO t") })
    }

    func testAFileAtTheSizeLimitIsClosedAndTheNextLineStartsAnother() throws {
        let writer = LogFileWriter(folder: folder, maxFileSize: 200, maxFiles: 50)
        for i in 0 ..< 20 { writer.append(level: "INFO", "line number \(i)") }
        writer.flush()

        XCTAssertGreaterThan(logFiles().count, 1)
        XCTAssertEqual(try lines().count, 20, "rolling over loses nothing")
    }

    func testOnlyTheNewestFilesStay() throws {
        let writer = LogFileWriter(folder: folder, maxFileSize: 1, maxFiles: 3)
        for i in 0 ..< 10 {
            writer.append(level: "INFO", "m\(i)")
            writer.flush()
        }

        XCTAssertEqual(logFiles().count, 3)
        XCTAssertEqual(try Set(lines().map { String($0.split(separator: " ").last!) }), ["m7", "m8", "m9"])
    }

    func testAfterCloseTheNextLineStartsAFreshFile() throws {
        let writer = LogFileWriter(folder: folder)
        writer.append(level: "INFO", "before")
        writer.close()
        writer.append(level: "INFO", "after")
        writer.flush()

        XCTAssertEqual(logFiles().count, 2)
        XCTAssertEqual(try lines().count, 2)
    }

    func testTheFolderRemovedFromUnderTheWriterComesBackWithTheNextFile() throws {
        let writer = LogFileWriter(folder: folder)
        writer.append(level: "INFO", "one")
        writer.close()
        try FileManager.default.removeItem(at: folder)
        writer.append(level: "INFO", "two")
        writer.flush()

        XCTAssertEqual(try lines().count, 1)
    }
}
