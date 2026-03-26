import Foundation

enum CamperMacrosError: CustomStringConvertible, Error {
    case loggersNotCorrectType
    case loggersCategoriesNotFound
    case ioModelIncorrectType
    case stringIncorrectType
    case environmentValueIncorrectType
    case environmentValueDefaultValue
    case hexColorInvalidValue

    case injectionIncorrectType
    case injectionIncorrectName
    case injectorIncorrectType
    case injectorNonDynamicType
    case outputIncorrectType
    case outputUnknowType
    case dependencyIncorrectType
    case dependencyUnknowType
    case passedIncorrectType

    case autoMockableIncorrectType
    case memberwiseInitIncorrectType

    var description: String {
        switch self {
        case .loggersNotCorrectType: return "@LoggersCollection can only be applied to enum"
        case .loggersCategoriesNotFound: return "Must contains 'Categories' enum with at least one case value"
        case .ioModelIncorrectType: return "@IOModel can only be applied to class"
        case .stringIncorrectType: return "@StringRepresentable can only be applied to enum"
        case .environmentValueIncorrectType: return "@EnvironmentValue can only be applied to variable"
        case .environmentValueDefaultValue: return "@EnvironmentValue must have default value"
        case .hexColorInvalidValue: return "#hexColor accept only next formats: '#rgb' '#rgba' '#rrggbb' '#rrggbbaa' '0xrgb' '0xrgba' '0xrrggbb' '0xrrggbbaa'"
        case .injectionIncorrectType: return "@Injection can only be applied to protocol"
        case .injectionIncorrectName: return "@Injection protocol name must end up with 'Injection'"
        case .injectorIncorrectType: return "@Injector can only be applied to class"
        case .injectorNonDynamicType: return "@Injector with '.subscript' properties must be '@dynamicMemberLookup'"
        case .outputIncorrectType: return "@Output can only be applied to variables"
        case .outputUnknowType: return "@Output must have explicit type declaration"
        case .dependencyIncorrectType: return "@Dependency can only be applied to variables"
        case .dependencyUnknowType: return "@Dependency must have explicit type declaration"
        case .passedIncorrectType: return "@Passed can only be applied to 'optional' variables"
        case .autoMockableIncorrectType: return "@AutoMockable can only be applied to protocol"
        case .memberwiseInitIncorrectType: return "@MemberwiseInit can only be applied to struct"
        }
    }
}
