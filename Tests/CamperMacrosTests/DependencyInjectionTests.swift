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
                var _analytics: AnalyticsService!
                var analytics: AnalyticsService {
                    _analytics
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
                var settings: SettingsInjection {
                    SettingsInjectionMock()
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
                @Origin("analytics.tracker") var tracker: Tracker { get }
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
                var _detail: DetailService!
                var detail: DetailService {
                    _detail
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
                var coordinator: Coordinator?
                var _analytics: AnalyticsService!
                var analytics: AnalyticsService {
                    _analytics
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
                var _analytics: AnalyticsService!
                var analytics: AnalyticsService {
                    _analytics
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
