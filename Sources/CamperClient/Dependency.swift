import Camper

final class SomeDependency: Sendable {}

enum SomeDependencyMock {
    static let mock = SomeDependency()
}

class SomeDependency2 {}

@Injector
@dynamicMemberLookup
final class ModuleInjector {
    @Dependency(.subscript) var someDependency: SomeDependency // = SomeDependency()
    @Output(.internal, .subscript) var someDependency2: SomeDependency2 = SomeDependency2()
}

@Injection(build: true)
protocol ViewModelInjection {
    var someDependency: SomeDependency { get }
    var someDependency2: SomeDependency2 { get }
    var childInj: ViewModel2Injection { get }
}

@Injection(injectorType: ModuleInjector.self)
protocol ViewModel2Injection {
    @Passed var dependency2: SomeDependency2? { get }
}

final class ModuleInjectorDependenciesImpl: ModuleInjector.Dependencies {
    let someDependency: SomeDependency = SomeDependency()
}
    
func checkDependency() {
    let module = ModuleInjector(dependencies: ModuleInjectorDependenciesImpl())
    _ = ViewModelInjectionImpl(injector: module)
    _ = ViewModel2InjectionMock()
}

// MARK: - Usage examples

func usageExamples() {
    // Basic mock — all dependencies use their default mocks
    let defaultMock = ModuleInjector.mock()

    // Configured mock — override a specific dependency
    let customMock = ModuleInjector.mock { deps in
        deps.someDependency = SomeDependency()
    }

    // ViewModelInjectionMock auto-resolves from DefaultInjector.mock()
    let viewModelMock = ViewModelInjectionMock()

    // ViewModelInjectionMock with a custom injector
    let viewModelMockWithCustomInjector = ViewModelInjectionMock(injector: customMock)

    _ = defaultMock
    _ = viewModelMock
    _ = viewModelMockWithCustomInjector
}

@MainActor
final class SideMenuCoordinator {
}

@Injection
protocol SideMenuCoordinatorInjection {
    var coordinator: SideMenuCoordinator? { get set }
}
