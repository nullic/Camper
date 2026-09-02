import Foundation

/// A value that can ride inside a `@StringRepresentable` case, after the dot.
///
/// The macro writes `case.value` and reads it back, so it needs one question answered about
/// the associated value: how does it spell itself, and how is it read from that spelling.
/// Two kinds of value already answer it and conform for free —
///
/// - anything the standard library can write and re-read (`Int`, `String`, `Double`, `Bool`),
/// - anything that already names itself with a string, another `@StringRepresentable` enum
///   included.
///
/// It exists because the macro used to assume the second shape and ask every value for a
/// `rawValue`: the documented `settings(id: Int)` example did not compile, and nobody noticed
/// for as long as the tests compared the expansion as text instead of building it.
///
/// A type that is both `LosslessStringConvertible` and `RawRepresentable where RawValue ==
/// String` has two answers and must pick one itself.
///
/// Reading is a static function and deliberately not an initializer: conforming `Int` and
/// `String` would then carry one more `init` taking a string, and an unapplied `Int.init`
/// somewhere else in the program becomes ambiguous. One such call site existed.
public protocol StringRepresentableValue {
    static func read(fromStringRepresentation text: String) -> Self?
    var stringRepresentation: String { get }
}

public extension StringRepresentableValue where Self: LosslessStringConvertible {
    static func read(fromStringRepresentation text: String) -> Self? {
        Self(text)
    }

    var stringRepresentation: String {
        String(self)
    }
}

public extension StringRepresentableValue where Self: RawRepresentable, RawValue == String {
    static func read(fromStringRepresentation text: String) -> Self? {
        Self(rawValue: text)
    }

    var stringRepresentation: String {
        rawValue
    }
}

extension Int: StringRepresentableValue {}
extension Int8: StringRepresentableValue {}
extension Int16: StringRepresentableValue {}
extension Int32: StringRepresentableValue {}
extension Int64: StringRepresentableValue {}
extension UInt: StringRepresentableValue {}
extension Double: StringRepresentableValue {}
extension Float: StringRepresentableValue {}
extension Bool: StringRepresentableValue {}
extension String: StringRepresentableValue {}
extension Substring: StringRepresentableValue {}
extension Character: StringRepresentableValue {}
