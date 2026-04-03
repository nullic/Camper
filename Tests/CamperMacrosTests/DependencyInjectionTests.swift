import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CamperMacros

final class DependencyMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Dependency": Dependency.self,
    ]

    func testDependencyAccessor() {
        assertMacroExpansion(
            """
            @Dependency
            var api: APIService
            """,
            expandedSource: """
            var api: APIService {
                get {
                    dependencies.api
                }
            }
            """,
            macros: testMacros
        )
    }

    func testDependencyExplicit() {
        assertMacroExpansion(
            """
            @Dependency(.explicit)
            var settings: AppSettings
            """,
            expandedSource: """
            var settings: AppSettings {
                get {
                    _explicitDependencies.settings
                }
            }
            """,
            macros: testMacros
        )
    }

    func testDependencyAppliedToNonVariable() {
        assertMacroExpansion(
            """
            @Dependency
            func doSomething() {}
            """,
            expandedSource: """
            func doSomething() {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Dependency must have explicit type declaration", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }
}

final class OutputMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Output": Output.self,
    ]

    func testOutputValidation() {
        assertMacroExpansion(
            """
            @Output
            var router: Router
            """,
            expandedSource: """
            var router: Router
            """,
            macros: testMacros
        )
    }

    func testOutputWithoutType() {
        assertMacroExpansion(
            """
            @Output
            var router = Router()
            """,
            expandedSource: """
            var router = Router()
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Output must have explicit type declaration", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }
}

final class PassedMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Passed": Passed.self,
    ]

    func testPassedOptional() {
        assertMacroExpansion(
            """
            @Passed
            var coordinator: Coordinator?
            """,
            expandedSource: """
            var coordinator: Coordinator?
            """,
            macros: testMacros
        )
    }

    func testPassedNonOptional() {
        assertMacroExpansion(
            """
            @Passed
            var coordinator: Coordinator
            """,
            expandedSource: """
            var coordinator: Coordinator
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Passed can only be applied to 'optional' variables", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }
}

final class InjectionMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Injection": Injection.self,
        "Origin": Origin.self,
        "Passed": Passed.self,
    ]

    // Default: mock: true — generates *Impl + *Mock
    func testBasicInjection() {
        assertMacroExpansion(
            """
            @Injection
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
            }
            """,
            expandedSource: """
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
            }

            internal final class HomeInjectionImpl: HomeInjection, PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable {
                private var __passedObjects: [String: WeakRef] = [:]
                private weak var parent: PassedObjectsInjection?
                private let injector: DefaultInjector
                internal var description: String {
                    "\\(type(of: self)) -> \\(parent != nil ? String(describing: parent!) : "nil")"
                }
                internal init(injector: DefaultInjector, parent: PassedObjectsInjection? = nil) {
                    self.injector = injector
                    self.parent = parent
                }
                internal func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject {
                    return __passedObjects["\\(ObjectType.self)"]?.value as? ObjectType ?? parent?.getPassedObject()
                }
                internal func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject {
                    __passedObjects["\\(ObjectType.self)"] = object != nil ? WeakRef(object!) : nil
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
            }

            internal final class HomeInjectionMock: HomeInjection, @unchecked Sendable {
                internal let injector: DefaultInjector
                internal init(injector: DefaultInjector = DefaultInjector.mock()) {
                    self.injector = injector
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
            }
            """,
            macros: testMacros
        )
    }

    // mock: false — generates only *Impl
    func testInjectionMockFalse() {
        assertMacroExpansion(
            """
            @Injection(mock: false)
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
            }
            """,
            expandedSource: """
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
            }

            internal final class HomeInjectionImpl: HomeInjection, PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable {
                private var __passedObjects: [String: WeakRef] = [:]
                private weak var parent: PassedObjectsInjection?
                private let injector: DefaultInjector
                internal var description: String {
                    "\\(type(of: self)) -> \\(parent != nil ? String(describing: parent!) : "nil")"
                }
                internal init(injector: DefaultInjector, parent: PassedObjectsInjection? = nil) {
                    self.injector = injector
                    self.parent = parent
                }
                internal func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject {
                    return __passedObjects["\\(ObjectType.self)"]?.value as? ObjectType ?? parent?.getPassedObject()
                }
                internal func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject {
                    __passedObjects["\\(ObjectType.self)"] = object != nil ? WeakRef(object!) : nil
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInjectionWithNestedInjection() {
        assertMacroExpansion(
            """
            @Injection
            protocol HomeInjection {
                var settings: SettingsInjection { get }
            }
            """,
            expandedSource: """
            protocol HomeInjection {
                var settings: SettingsInjection { get }
            }

            internal final class HomeInjectionImpl: HomeInjection, PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable {
                private var __passedObjects: [String: WeakRef] = [:]
                private weak var parent: PassedObjectsInjection?
                private let injector: DefaultInjector
                internal var description: String {
                    "\\(type(of: self)) -> \\(parent != nil ? String(describing: parent!) : "nil")"
                }
                internal init(injector: DefaultInjector, parent: PassedObjectsInjection? = nil) {
                    self.injector = injector
                    self.parent = parent
                }
                internal func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject {
                    return __passedObjects["\\(ObjectType.self)"]?.value as? ObjectType ?? parent?.getPassedObject()
                }
                internal func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject {
                    __passedObjects["\\(ObjectType.self)"] = object != nil ? WeakRef(object!) : nil
                }
                var settings: SettingsInjection {
                    SettingsInjectionImpl(injector: injector, parent: self)
                }
            }

            internal final class HomeInjectionMock: HomeInjection, @unchecked Sendable {
                internal let injector: DefaultInjector
                internal init(injector: DefaultInjector = DefaultInjector.mock()) {
                    self.injector = injector
                }
                var settings: SettingsInjection {
                    SettingsInjectionMock(injector: injector)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInjectionWithOrigin() {
        assertMacroExpansion(
            """
            @Injection(mock: false)
            protocol HomeInjection {
                @Origin("analytics.tracker") var tracker: Tracker { get }
                var api: APIService { get }
            }
            """,
            expandedSource: """
            protocol HomeInjection {
                var tracker: Tracker { get }
                var api: APIService { get }
            }

            internal final class HomeInjectionImpl: HomeInjection, PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable {
                private var __passedObjects: [String: WeakRef] = [:]
                private weak var parent: PassedObjectsInjection?
                private let injector: DefaultInjector
                internal var description: String {
                    "\\(type(of: self)) -> \\(parent != nil ? String(describing: parent!) : "nil")"
                }
                internal init(injector: DefaultInjector, parent: PassedObjectsInjection? = nil) {
                    self.injector = injector
                    self.parent = parent
                }
                internal func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject {
                    return __passedObjects["\\(ObjectType.self)"]?.value as? ObjectType ?? parent?.getPassedObject()
                }
                internal func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject {
                    __passedObjects["\\(ObjectType.self)"] = object != nil ? WeakRef(object!) : nil
                }
                var tracker: Tracker {
                    injector.analytics.tracker
                }
                var api: APIService {
                    injector.api
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInjectionInheritance() {
        assertMacroExpansion(
            """
            @Injection(mock: false)
            protocol DetailInjection: HomeInjection {
                var detail: DetailService { get }
            }
            """,
            expandedSource: """
            protocol DetailInjection: HomeInjection {
                var detail: DetailService { get }
            }

            internal class DetailInjectionImpl: HomeInjectionImpl, DetailInjection {
                var detail: DetailService {
                    injector.detail
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInjectionInheritanceWithMock() {
        assertMacroExpansion(
            """
            @Injection
            protocol DetailInjection: HomeInjection {
                var detail: DetailService { get }
            }
            """,
            expandedSource: """
            protocol DetailInjection: HomeInjection {
                var detail: DetailService { get }
            }

            internal class DetailInjectionImpl: HomeInjectionImpl, DetailInjection {
                var detail: DetailService {
                    injector.detail
                }
            }

            internal class DetailInjectionMock: HomeInjectionMock, DetailInjection {
                var detail: DetailService {
                    injector.detail
                }
            }
            """,
            macros: testMacros
        )
    }

    // Mock always uses injector — tests that injector:DefaultInjector.mock() is the default
    func testInjectionMockWithAllVariants() {
        assertMacroExpansion(
            """
            @Injection
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
                var settings: SettingsInjection { get }
                var coordinator: Coordinator? { get set }
            }
            """,
            expandedSource: """
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
                var settings: SettingsInjection { get }
                var coordinator: Coordinator? { get set }
            }

            internal final class HomeInjectionImpl: HomeInjection, PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable {
                private var __passedObjects: [String: WeakRef] = [:]
                private weak var parent: PassedObjectsInjection?
                private let injector: DefaultInjector
                internal var description: String {
                    "\\(type(of: self)) -> \\(parent != nil ? String(describing: parent!) : "nil")"
                }
                internal init(injector: DefaultInjector, parent: PassedObjectsInjection? = nil) {
                    self.injector = injector
                    self.parent = parent
                }
                internal func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject {
                    return __passedObjects["\\(ObjectType.self)"]?.value as? ObjectType ?? parent?.getPassedObject()
                }
                internal func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject {
                    __passedObjects["\\(ObjectType.self)"] = object != nil ? WeakRef(object!) : nil
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
                var settings: SettingsInjection {
                    SettingsInjectionImpl(injector: injector, parent: self)
                }
                var coordinator: Coordinator? {
                    get {
                        getPassedObject()
                    }
                    set {
                        setPassedObject(newValue)
                    }
                }
            }

            internal final class HomeInjectionMock: HomeInjection, @unchecked Sendable {
                internal let injector: DefaultInjector
                internal init(injector: DefaultInjector = DefaultInjector.mock()) {
                    self.injector = injector
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
                var settings: SettingsInjection {
                    SettingsInjectionMock(injector: injector)
                }
                var coordinator: Coordinator?
            }
            """,
            macros: testMacros
        )
    }

    func testInjectionWithCustomInjectorType() {
        assertMacroExpansion(
            """
            @Injection(injectorType: ModuleInjector.self)
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
            }
            """,
            expandedSource: """
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
            }

            internal final class HomeInjectionImpl: HomeInjection, PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable {
                private var __passedObjects: [String: WeakRef] = [:]
                private weak var parent: PassedObjectsInjection?
                private let injector: ModuleInjector
                internal var description: String {
                    "\\(type(of: self)) -> \\(parent != nil ? String(describing: parent!) : "nil")"
                }
                internal init(injector: ModuleInjector, parent: PassedObjectsInjection? = nil) {
                    self.injector = injector
                    self.parent = parent
                }
                internal func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject {
                    return __passedObjects["\\(ObjectType.self)"]?.value as? ObjectType ?? parent?.getPassedObject()
                }
                internal func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject {
                    __passedObjects["\\(ObjectType.self)"] = object != nil ? WeakRef(object!) : nil
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
            }

            internal final class HomeInjectionMock: HomeInjection, @unchecked Sendable {
                internal let injector: ModuleInjector
                internal init(injector: ModuleInjector = ModuleInjector.mock()) {
                    self.injector = injector
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInjectionInheritanceWithMockUsesInjector() {
        assertMacroExpansion(
            """
            @Injection
            protocol DetailInjection: HomeInjection {
                var detail: DetailService { get }
            }
            """,
            expandedSource: """
            protocol DetailInjection: HomeInjection {
                var detail: DetailService { get }
            }

            internal class DetailInjectionImpl: HomeInjectionImpl, DetailInjection {
                var detail: DetailService {
                    injector.detail
                }
            }

            internal class DetailInjectionMock: HomeInjectionMock, DetailInjection {
                var detail: DetailService {
                    injector.detail
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInjectionIncorrectName() {
        assertMacroExpansion(
            """
            @Injection
            protocol HomeService {
                var api: API { get }
            }
            """,
            expandedSource: """
            protocol HomeService {
                var api: API { get }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Injection protocol name must end up with 'Injection'", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    // { get set } properties are treated as passed objects automatically
    func testInjectionGetSet() {
        assertMacroExpansion(
            """
            @Injection
            protocol HomeInjection {
                var coordinator: Coordinator? { get set }
                var analytics: AnalyticsService { get }
            }
            """,
            expandedSource: """
            protocol HomeInjection {
                var coordinator: Coordinator? { get set }
                var analytics: AnalyticsService { get }
            }

            internal final class HomeInjectionImpl: HomeInjection, PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable {
                private var __passedObjects: [String: WeakRef] = [:]
                private weak var parent: PassedObjectsInjection?
                private let injector: DefaultInjector
                internal var description: String {
                    "\\(type(of: self)) -> \\(parent != nil ? String(describing: parent!) : "nil")"
                }
                internal init(injector: DefaultInjector, parent: PassedObjectsInjection? = nil) {
                    self.injector = injector
                    self.parent = parent
                }
                internal func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject {
                    return __passedObjects["\\(ObjectType.self)"]?.value as? ObjectType ?? parent?.getPassedObject()
                }
                internal func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject {
                    __passedObjects["\\(ObjectType.self)"] = object != nil ? WeakRef(object!) : nil
                }
                var coordinator: Coordinator? {
                    get {
                        getPassedObject()
                    }
                    set {
                        setPassedObject(newValue)
                    }
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
            }

            internal final class HomeInjectionMock: HomeInjection, @unchecked Sendable {
                internal let injector: DefaultInjector
                internal init(injector: DefaultInjector = DefaultInjector.mock()) {
                    self.injector = injector
                }
                var coordinator: Coordinator?
                var analytics: AnalyticsService {
                    injector.analytics
                }
            }
            """,
            macros: testMacros
        )
    }

    // build: true — generates *Impl + *Mock + build()
    func testInjectionBuildTrue() {
        assertMacroExpansion(
            """
            @Injection(build: true)
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
            }
            """,
            expandedSource: """
            protocol HomeInjection {
                var analytics: AnalyticsService { get }
            }

            internal final class HomeInjectionImpl: HomeInjection, PassedObjectsInjection, CustomStringConvertible, @unchecked Sendable {
                private var __passedObjects: [String: WeakRef] = [:]
                private weak var parent: PassedObjectsInjection?
                private let injector: DefaultInjector
                internal var description: String {
                    "\\(type(of: self)) -> \\(parent != nil ? String(describing: parent!) : "nil")"
                }
                internal init(injector: DefaultInjector, parent: PassedObjectsInjection? = nil) {
                    self.injector = injector
                    self.parent = parent
                }
                internal func getPassedObject<ObjectType>() -> ObjectType? where ObjectType: AnyObject {
                    return __passedObjects["\\(ObjectType.self)"]?.value as? ObjectType ?? parent?.getPassedObject()
                }
                internal func setPassedObject<ObjectType>(_ object: ObjectType?) where ObjectType: AnyObject {
                    __passedObjects["\\(ObjectType.self)"] = object != nil ? WeakRef(object!) : nil
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
            }

            internal final class HomeInjectionMock: HomeInjection, @unchecked Sendable {
                internal let injector: DefaultInjector
                internal init(injector: DefaultInjector = DefaultInjector.mock()) {
                    self.injector = injector
                }
                var analytics: AnalyticsService {
                    injector.analytics
                }
            }

            func build(injector: DefaultInjector) -> HomeInjection {
                HomeInjectionImpl(injector: injector)
            }
            """,
            macros: testMacros
        )
    }
}

final class InjectorMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Injector": Injector.self,
        "Dependency": Dependency.self,
        "Output": Output.self,
    ]

    func testInjectorMockWithDependencies() {
        assertMacroExpansion(
            """
            @Injector(mock: true, dependenciesMock: true)
            final class AppInjector {
                @Dependency var api: APIService
                @Output var router: Router = Router()
            }
            """,
            expandedSource: """
            final class AppInjector {
                var api: APIService {
                    get {
                        dependencies.api
                    }
                }
                var router: Router = Router()

                internal protocol Outputs {
                    var router: Router {
                        get
                    }
                    func getValue() -> Router
                }

                internal protocol Dependencies {
                    var api: APIService {
                        get
                    }
                }

                private let dependencies: Dependencies

                internal init(dependencies: Dependencies) {
                    self.dependencies = dependencies
                }

                internal func getValue() -> APIService {
                    api
                }

                internal func getValue() -> Router {
                    router
                }
            }

            internal enum AppInjectorMock {
                internal static func mock(configure: (AppInjector.DependenciesMock) -> Void = { _ in
                    }) -> AppInjector {
                    let deps = AppInjector.DependenciesMock()
                    configure(deps)
                    return AppInjector(dependencies: deps)
                }
            }

            typealias DefaultInjector = AppInjector

            extension AppInjector {
                internal static func mock(configure: (DependenciesMock) -> Void = { _ in
                    }) -> AppInjector {
                    AppInjectorMock.mock(configure: configure)
                }
                internal final class DependenciesMock: AppInjector.Dependencies {
                    internal var api: APIService = APIServiceMock.mock()
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInjectorMockWithDefaultParameters() {
        assertMacroExpansion(
            """
            @Injector
            final class AppInjector {
                @Dependency var api: APIService
                @Output var router: Router = Router()
            }
            """,
            expandedSource: """
            final class AppInjector {
                var api: APIService {
                    get {
                        dependencies.api
                    }
                }
                var router: Router = Router()

                internal protocol Outputs {
                    var router: Router {
                        get
                    }
                    func getValue() -> Router
                }

                internal protocol Dependencies {
                    var api: APIService {
                        get
                    }
                }

                private let dependencies: Dependencies

                internal init(dependencies: Dependencies) {
                    self.dependencies = dependencies
                }

                internal func getValue() -> APIService {
                    api
                }

                internal func getValue() -> Router {
                    router
                }
            }

            internal enum AppInjectorMock {
                internal static func mock(configure: (AppInjector.DependenciesMock) -> Void = { _ in
                    }) -> AppInjector {
                    let deps = AppInjector.DependenciesMock()
                    configure(deps)
                    return AppInjector(dependencies: deps)
                }
            }

            typealias DefaultInjector = AppInjector

            extension AppInjector {
                internal static func mock(configure: (DependenciesMock) -> Void = { _ in
                    }) -> AppInjector {
                    AppInjectorMock.mock(configure: configure)
                }
                internal final class DependenciesMock: AppInjector.Dependencies {
                    internal var api: APIService = APIServiceMock.mock()
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInjectorMockWithoutDependencies() {
        assertMacroExpansion(
            """
            @Injector(mock: true)
            final class AppInjector {
                @Output var router: Router = Router()
            }
            """,
            expandedSource: """
            final class AppInjector {
                var router: Router = Router()

                internal protocol Outputs {
                    var router: Router {
                        get
                    }
                    func getValue() -> Router
                }

                internal init() {
                }

                internal func getValue() -> Router {
                    router
                }
            }

            internal enum AppInjectorMock {
                internal static func mock() -> AppInjector {
                    AppInjector()
                }
            }

            typealias DefaultInjector = AppInjector

            extension AppInjector {
                internal static func mock() -> AppInjector {
                    AppInjectorMock.mock()
                }
            }
            """,
            macros: testMacros
        )
    }
}
