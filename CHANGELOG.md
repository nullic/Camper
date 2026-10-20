# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-10-20

### Changed
- The manifest asks for Swift tools 6.2 again. The package was never built on anything older: CI runs Xcode 26 only, and the Swift Package Index shows 6.1 failing on `OperationExecutor` (a non-sendable `PassthroughSubject` leaving a `nonisolated(unsafe)` property), so a lower number promised toolchains the package did not support. Projects written in Swift 5 language mode can still depend on it; only the compiler has to be 6.2 or newer.
- tvOS and watchOS build now. The only thing that stopped them was `OperationExecutor.stream(id:)` and `wait(id:)`: their `@available` named iOS (and macOS) only, so every other platform was treated as having them from its minimum, and `Task.Failure` is tvOS 18 / watchOS 11. With the platforms raised below the marks are no longer needed and are gone.
- **SwiftyBeaver is no longer a dependency of Camper.** It was used for one thing, appending lines to a file, and it has not been updated since November 2024. Camper now writes the file itself (`LogFileWriter`): one serial queue, the file held open and appended to with one `write` per line. Nothing public changed.
- The file log is now bounded. SwiftyBeaver's `logFileMaxSize` only applies when `logFileAmount > 1`, and it was 1, so the 15 MB that was set did nothing and every `configure()` left one more file that only grew. A file is now closed at 5 MB, the next line starts another, and only the newest five are kept.
- A log line reads `2026-10-20 14:03:11.482+02:00 ERROR [Network][File.swift:42 -- fn()]: message`: it carries the date and the UTC offset (the file name is in UTC), and no longer the `Logger.swift.log(_:_:file:function:line:):88` of Camper's own call that SwiftyBeaver put in front of every message. `.notice` is written as `NOTICE` rather than `INFO`.
- The log file is created by the first line written to it rather than by `configure()`, so a session that logs nothing leaves no empty file.
- **Minimum platforms are raised** to macOS 15, iOS 18, Mac Catalyst 18, tvOS 18, watchOS 11 and visionOS 2 (from macOS 14 / iOS 17 / Mac Catalyst 17; tvOS, watchOS and visionOS were not declared). Projects that deploy to iOS 17 or macOS 14 can no longer depend on Camper. The `@available` marks that only restated those numbers on `UniqueFindable` are gone.
- **`LogLevel` is the set of levels `os.Logger` has**: `debug, info, notice, warning, error, critical, fault`, and the internal copy of it is gone. `.notice` is new and no longer folded into `.info`, so `minimumLogLevel: .notice` drops `.debug` and `.info` calls as OSLog's own filtering does. `.verbose` never had a call of its own and stays as a deprecated name for `.debug`. The raw values of `.debug` and `.info` are now 0 and 1 (were 1 and 2); the rest are unchanged.
- `.spi.yml` limits the Swift Package Index builds to iOS, macOS, visionOS, tvOS and watchOS. Linux and Android have no `os` module, so those showed as failures for platforms the package does not target.

### Fixed
- The package did not build for Mac Catalyst, a platform its manifest declares: the colour helpers in `HexColors.swift` took the `AppKit` branch there, where `NSColor` does not exist. That branch now leaves Catalyst out and the `UIKit` one serves it.

## [1.0.19] - 2026-10-10

### Fixed
- `logsToSend()` asked whether `logs.zip` was there and then replaced or moved it, and the answer could be stale by the time it was used: another process creating or deleting the archive in between made it throw «already exists» (516) or «no such file» (260). The archive is now put in place by one `rename(2)`, which replaces one that is there and makes one that is not.
- `LoggerConfiguratorTests` failed now and then under `swift test --parallel`: they share the one real logs folder, and a test in another process deleted the folder or the archive another was gathering. Each test now holds a lock across processes.

## [1.0.18] - 2026-10-10

### Added
- `@IOKey` marks the property `@IOModel` finds a record by — `unique(_:in:)`, `insert(_:in:)` updating the record it finds, `delete(_:in:)`, `replace(_:in:)`, `.link` — without asking the store for a unique constraint. A model synced through CloudKit cannot carry `@Attribute(.unique)`, since CloudKit refuses unique constraints, and until now that meant losing everything `@IOModel` builds on the key.
- Compound keys. Two or more `@IOKey` properties make one key: `UniqueID` becomes a `Hashable, Codable, Sendable` struct of them, in declaration order, and every key-taking method takes it — `Price.unique(Price.UniqueID(shop: "komplett", item: "XGIMI"), in: context)`. `replace(_:in:)` keeps the given keys and deletes the rest in memory, as a predicate cannot test a struct against a set.
- SwiftData's `#Unique<T>([\.a, \.b], …)` names the key too: its first set, when no property says `@IOKey`. The key comes from `@IOKey` first, then `#Unique`, then `@Attribute(.unique)`, so a single-key model expands exactly as before.

## [1.0.17] - 2026-09-15

### Fixed
- `logsToSend()` threw an opaque `LoggerDomain -1` on a machine that had logged nothing yet: the logs folder is made when file logging is configured, and gathered even when it is empty. A machine with nothing to say still has something to hand over, and CI — where no log had ever been written — is exactly that machine.
- The archive is now written under a name of its own and moved over the old one, rather than the old one being deleted first and copied over. Two callers arriving together raced: one deleted, both copied, and the second failed with «logs.zip already exists».

## [1.0.16] - 2026-09-15

### Changed
- `LoggerConfigurator.zipLogs()` is now `logsToSend()`. The old name said how it was done, and how it was done has just changed; every caller of it is asking for one thing — the logs as a single file to hand somewhere — and the name now says that. The old name stays as a deprecated call that forwards, so nothing built against 1.0.15 stops compiling.
- That file is gathered by the system's own file coordination (`NSFileCoordinator`, `.forUploading`) rather than by an archiver of ours, so **ZIPFoundation is no longer a dependency of Camper**. It arrives as the same `.zip` beside the logs folder.
- The manifest asks for Swift tools 6.0 rather than 6.2. Nothing in it or in the sources needed 6.2, and SPM refuses an older toolchain outright on the tools-version alone, so the higher number only turned away toolchains that would have built the package fine.
- swift-syntax now spans `600.0.0 ..< 604.0.0`, taking 603 where the graph allows it. Nothing in the macros needed changing; 603's pretty-printer breaks the line before `else`, so the eleven `IOModelMacroTests` fixtures that compare printed expansions were reshaped to match it.

### Removed
- The ZIPFoundation dependency. A dependency-injection library had no business carrying an archiver, and it travelled into the graph of everything that uses Camper.

### Documentation
- `@Injector`'s parameter table said `mock` and `dependenciesMock` default to `false`; both default to `true`, so the table told a reader to switch on what is already on.
- The same section called the generated `AppInjectorMock.mock` a property. It is `static func mock(configure:)`, and the line as written would not have compiled.
- Installation now names the floor the package actually stands on — Swift 6.0, macOS 14 / iOS 17 / Mac Catalyst 17 — and the two dependencies left.

## [1.0.15] - 2026-09-03

### Added
- `@SoftCodable` on an `enum` — `Codable` for a sum type, spelled for a document people author by hand: the case's snake_case name is the key and its value sits directly under it (`establish: {id: fact_log}`), a case with no value is a bare string (`finish`), and a case with several values writes each under its own name (`spend: {resource: doom, amount: 1}`). Previously the macro threw `@SoftCodable can only be applied to struct`, leaving the compiler's synthesised conformance, which spells a payload `_0` — legal, and unreadable in a file anyone opens. `@StringRepresentable` remains the answer where a whole case fits in one string; this is the answer where a case carries a record.
- The coder is emitted as **members** of the enum, not in an extension: an extension is not lexically inside the enclosing type, so a payload type declared beside the enum (`case establish(Fact)`) does not resolve there.

### Changed
- A case carrying two or more **unlabelled** values is refused with a diagnostic: each value is written under its own name, and an unlabelled one has none — falling back to `_0` / `_1` is the very thing this generates a coder to avoid. Label them, or wrap them in one value.
- Decoding a sum type is deliberately not soft: a struct falls back to a property's inline default, a sum type has nothing to fall back to, so a name no case answers to throws rather than silently decoding as something else.

## [1.0.11] - 2026-09-02

### Added
- `StringRepresentableValue` — the protocol an associated value must satisfy to ride inside a `@StringRepresentable` case: how it spells itself, and how it is read back. Anything `LosslessStringConvertible` (`Int`, `String`, `Double`, `Bool`, …) and anything `RawRepresentable where RawValue == String` (another `@StringRepresentable` enum included) conforms for free.
- `@StringRepresentable(.snakeCase)` — opt-in snake_case spelling for case names (`countdownStep` → `"countdown_step"`), for enums riding in a document whose every other key is snake_case. The conversion is `@SoftCodable`'s, so a run of capitals stays one word. `.caseName` remains the default: raw values already written to `@AppStorage` or a store must not change spelling under their readers.

### Fixed
- `@StringRepresentable` cases with an associated value never compiled unless the value was `RawRepresentable where RawValue == String`: the expansion asked the value for a `rawValue` and rebuilt it with `init?(rawValue:)` — neither of which `Int` or `String` has — and dropped the case's argument label (`.detail(value)` for `case detail(id: Int)`). The macro's own documented `case settings(id: Int)` example is among what did not build. Expansion now goes through `StringRepresentableValue` and keeps the label. **Breaking source change** for associated-value types that are neither `LosslessStringConvertible` nor string-`RawRepresentable`: conform them to `StringRepresentableValue`.
- A case with more than one associated value is now rejected with a diagnostic instead of being half-encoded — only the first value was ever read back, so the rest went out and never came back. The encoding has a single degree of freedom (its tail), so exactly one value may itself contain a dot; wrap two in one value.

### Changed
- `CamperTests` and `CamperClient` now use `@StringRepresentable` for real (compiled, not compared as text), which is what surfaced the above; `StringRepresentableMacroTests` alone only ever checked the shape of the expansion, never that it builds.

## [1.0.10] - 2026-09-01

### Added
- `@SoftKey("...")` — names the key a `@SoftCodable` property is written under, where the derived snake_case cannot spell it: an acronym next to another (`requiredPCID` → `required_pc_id`) or a pluralised one (`presentNPCs` → `present_npcs`).
- `@SoftRequired` — keeps a key required on decode even though the property carries an inline default, so the default serves only the generated initializer (e.g. `schema_version` must be in the file, while code building a value in memory gets the current version for free).

### Fixed
- `@SoftCodable` key derivation put an underscore before every capital, so `backendID` became `backend_i_d` and `revealsNPCIds` became `reveals_n_p_c_ids`. A run of capitals is now read as one word. Paired with soft decoding this was the worst kind of wrong: the reader asked for a key nobody wrote and silently got the property's default instead of throwing. **Breaking wire change** for any persisted document whose keys were written with the old spelling — re-encode, or pin the old key with `@SoftKey`.

## [1.0.9] - 2026-07-27

### Fixed
- `@MemberwiseInit` dropped explicit default values: `let verbose: Bool = false` became a required parameter. Defaults are now preserved in the generated `init`.

### Changed
- `MemberwiseInitMacro` reuses the shared `VariableDeclSyntax` helpers instead of its own `StoredProperty` type; added a `StructDeclSyntax` extension (mirroring the existing actor/class ones) for `inputVariables`, `computedVariables`, and privacy helpers.
- Modifier checks across the actor/class/struct/variable syntax extensions compare `tokenKind` against keyword cases instead of matching `modifiers.name.text` strings.

## [1.0.8] - 2026-06-26

### Changed
- swift-syntax dependency widened to `600.0.0 ..< 603.0.0` so Camper co-resolves with packages that pin 600 (e.g. mlx-swift-lm via mlx-audio-swift). SPM still picks 602 when nothing forces lower.
- swift-syntax is declared under its canonical `swiftlang/swift-syntax` URL (`apple/swift-syntax` is now only a redirect). Two URLs for one package identity is a warning today and a hard SwiftPM error in newer toolchains.

## [1.0.7] - 2026-06-11

### Fixed
- `@Dependency(.subscript)` generated a `@dynamicMemberLookup` subscript at the dependency's read privacy, which is often narrower than the enclosing type's — Swift requires the subscript to be at least as accessible as its type. It now uses the type's access level.

## [1.0.6] - 2026-06-10

### Added
- `@SoftCodable` — generates `Codable` conformance with snake_case `CodingKeys` and soft-fail decoding: a missing key falls back to the property's inline default, an optional decodes to `nil`, and a non-optional without a default stays required. `init(from:)` / `encode(to:)` are emitted in an extension, so the struct keeps its implicit memberwise initializer.
- `@SoftIgnore` — skips a stored property entirely (neither encoded nor decoded); it must carry an inline default, which it is set to on decode. For transient or non-`Codable` state.
- `@SoftCodable` also emits a **public** memberwise `init` for public structs — the implicit one is `internal`, which is not enough to be used as a default argument outside the module.

### Fixed
- `initializerValue` used the full description of the default value, so a trailing line comment (`var x = "" // note`) corrupted the generated code; it now trims trivia.

## [1.0.5] - 2026-05-28

### Added
- `FilePathInfo` conforms to `Hashable` and `Identifiable` (`id = self`), so SwiftUI diffing picks up size/date changes on the same path.

### Changed
- `FilePathInfo` replaces its single `date` with explicit `modificationDate` and `creationDate`, each falling back to the other so callers never handle `nil`. **Breaking source change.**
- `FolderMonitor` logs directory-read failures instead of swallowing them.

## [1.0.4] - 2026-05-26

### Added
- `@UserDefault` and `@CodableUserDefault` now integrate with SwiftUI's `ObservableObject` via the `_enclosingInstance` static-subscript pattern (same mechanism `@Published` uses). When the host class conforms to `ObservableObject`, every setter automatically fires `objectWillChange.send()`, so `@ObservedObject` / `@StateObject` listeners re-render. Non-`ObservableObject` hosts (structs, plain classes) keep using `wrappedValue` directly — no behaviour change for legacy call sites.

## [1.0.3] - 2026-05-15

### Added
- Adaptive `#hexColor(light, dark)` (string- and integer-literal forms) returning a plain SwiftUI `Color`: it expands to a `UIColor`-backed adaptive color on UIKit hosts and an `NSColor`-backed one on AppKit hosts, so cross-platform palette code no longer needs a `#if canImport(UIKit)` switch per entry. The expansion stays a single expression, usable in computed-property bodies.

## [1.0.2] - 2026-05-15

### Fixed
- `#localized("…", .main)` wrapped the bundle as `.atURL(Bundle.main.bundleURL)`, a shape Xcode's String Catalog extractor does not recognise, so every key emitted through it was tagged `"extractionState": "stale"`. `.main` is now passed through as the literal `bundle: .main`; every other accessor (`.module`, custom bundles) still goes through the URL form.

## [1.0.1] - 2026-05-15

### Fixed
- `#hexNSColor(light, dark)` picked its branch with `$0.name == .aqua`, which matches only the bare `.aqua` appearance — `.vibrantLight` (popovers, sidebars, sheets) and the high-contrast accessibility variants fell through to the dark color. It now uses `bestMatch(from: [.aqua, .darkAqua])`.

### Changed
- CI: `actions/checkout` bumped to v5; Xcode matrix expanded to 26.0.1 and 26.3.

## [1.0.0] - 2026-04-30

### Added
- `Camper.LogLevel` enum so callers no longer need to import SwiftyBeaver to set `minimumLogLevel`.
- `OperationError` — a `Sendable`-conforming wrapper for the error stored in `OperationState.failed`.
- `@MockName("...")` macro for overriding the auto-generated unique-name prefix in `@AutoMockable` mocks.
- Multicast `OperationExecutor.stream(id:)`: each subscription gets its own `AsyncSequence` instead of competing with peers over a shared continuation.
- `OperationExecutor.wait(id:)` returns immediately when the operation is already finished (snapshot fallback).
- Camper-side runtime tests (`Tests/CamperTests/`) covering property wrappers, `OperationExecutor`, `LoggerConfigurator` (with concurrent stress test), `TaskQueue`, `ObservationContainer`, value transformers (incl. cold-start round-trip), and an `@IOModel` SwiftData integration suite.
- `@AutoMockable` macro tests including `@MockName` overrides and Dictionary-vs-Array regression guard.
- GitHub Actions CI on macOS 15 with Xcode 16.2 / 16.3.

### Changed
- `LoggerConfigurator` is now an `enum` namespace backed by `OSAllocatedUnfairLock<State>` instead of an `actor` with `nonisolated(unsafe)` static state.
- `OperationState.failed` payload is now `OperationError` (was `Error`). Pattern-matching against a specific error type is no longer possible — use `error.description` / `error.underlyingTypeName` instead. **Breaking source change.**
- `LoggerConfigurator.configure(minimumLogLevel:)` now takes `Camper.LogLevel` (was `SwiftyBeaver.Level`). **Breaking source change** for callers that imported and named `SwiftyBeaver.Level` explicitly.
- `JSONValueTransformer<ValueType>` constraint tightened from `Codable` to `Codable & NSObject` (Core Data transformable attributes require an in-memory class type). **Breaking source change** for value-type Codable users.

### Fixed
- `AnySecureCodingValueTransformer` / `JSONValueTransformer`: replaced `try!` with `try?` so corrupted persisted data returns `nil` instead of crashing the process on read.
- `transformedValueClass()` now returns `ValueType.self` (the in-memory attribute type) — previously the cast was malformed and would crash for struct-`Codable` types.
- `OperationExecutor.stream(id:)` events were split across concurrent subscribers; each subscriber now sees every event.
- `OperationExecutor.wait(id:)` could hang forever if the operation finished before the wait subscribed.
- `LoggerConfigurator` had truly unsynchronized mutable state behind a fictitious `actor`; reads/writes are now serialized through an unfair lock.
- `@IOModel` `notify()` no longer emits an unused `guard let object` binding when the class has no observable variables.
- `@AutoMockable`'s `typeIdentifier` mistakenly applied the array `s` suffix to dictionary types (`[K: V]` → `…StringStrings`); now uses `ArrayTypeSyntax` to distinguish.
- `@Injector` `ExtensionMacro` guard threw `CamperMacrosError.ioModelIncorrectType` instead of `injectorIncorrectType`.
- `PassedObjectsInjection` protocol now declares `setPassedObject(_:)` (it was generated on the impl but missing from the public protocol).
- `LazyAtomic`, `UserDefault`, `CodableUserDefault` gained `init(wrappedValue:)` so the documented `@Wrapper(...) var x = default` syntax compiles.

### Removed
- Dead `InjectorOutputs` marker protocol (was unused).
- Dead `@EnvironmentValue` error cases in `CamperMacrosError` (the macro itself was never implemented).
- Unused `notificationObserver` field in `ObservationContainer`.
- README section about `@Clamped` / `@ClampedNil` — those property wrappers were never implemented.

### Documentation
- Aligned README with the actual API for property wrappers, `LoggerConfigurator`, and `@LoggersCollection`.
- Added an `OperationExecutor` section, documented the `<CATEGORY>_LOGS` env-variable gating pattern, and added file-log helpers.
- Added "Known limitations" notes to `@AutoMockable` and `@IOModel` documentation.
