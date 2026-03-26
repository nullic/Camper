import Camper

final class SomeDependency: Sendable {}

enum SomeDependencyMock {
    static let mock = SomeDependency()
}

class SomeDependency2 {}

@Injector(mock: true, dependenciesMock: true)
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
