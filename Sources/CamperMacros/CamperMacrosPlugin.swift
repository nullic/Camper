import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct CamperMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LoggersCollectionMacro.self,
        StringRepresentableMacro.self,
        HexColorMacro.self,
        LocalizedMacro.self,

        IOModel.self,
        IOAttribute.self,

        Injection.self,
        Injector.self,
        Dependency.self,
        Output.self,
        Passed.self,
        Origin.self,
        AutoMockable.self,
        MockName.self,
        MemberwiseInit.self,
    ]
}
