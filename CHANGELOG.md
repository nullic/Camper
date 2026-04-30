# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
