import Foundation

enum CamperMacrosError: CustomStringConvertible, Error {
    case loggersNotCorrectType
    case loggersCategoriesNotFound
    case ioModelIncorrectType
    case stringIncorrectType
    case stringMultipleAssociatedValues(caseName: String)
    case hexColorInvalidValue
    case cssColorInvalidValue

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
    case softCodableIncorrectType
    case softCodableUnlabelledValues(caseName: String)

    var description: String {
        switch self {
        case .loggersNotCorrectType: return "@LoggersCollection can only be applied to enum"
        case .loggersCategoriesNotFound: return "Must contains 'Categories' enum with at least one case value"
        case .ioModelIncorrectType: return "@IOModel can only be applied to class"
        case .stringIncorrectType: return "@StringRepresentable can only be applied to enum"
        case .stringMultipleAssociatedValues(let caseName):
            return "@StringRepresentable writes one value after the dot, and `\(caseName)` carries more than one — there is no spelling that reads them all back. Wrap them in one value."
        case .hexColorInvalidValue: return "#hexColor accept only next formats: '#rgb' '#rgba' '#rrggbb' '#rrggbbaa' '0xrgb' '0xrgba' '0xrrggbb' '0xrrggbbaa'"
        case .cssColorInvalidValue: return "#cssColor accept only next formats: '#rgb' '#rgba' '#rrggbb' '#rrggbbaa' 'rgb(r, g, b)' 'rgba(r, g, b, a)'"
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
        case .softCodableIncorrectType: return "@SoftCodable can only be applied to a struct or an enum"
        case .softCodableUnlabelledValues(let caseName):
            return "@SoftCodable writes each of a case's values under its own name, and `\(caseName)` carries more than one unlabelled value — there is no name to write them under. Label them, or wrap them in one value."
        }
    }
}
