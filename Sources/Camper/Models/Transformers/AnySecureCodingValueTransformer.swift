import Foundation

public final class AnySecureCodingValueTransformer<ValueType: NSSecureCoding & NSObject>: ValueTransformer {
    public static var name: NSValueTransformerName { NSValueTransformerName(rawValue: "AnySecureCodingValueTransformer<\(ValueType.self)>") }

    public static func register() {
        ValueTransformer.setValueTransformer(Self(), forName: name)
    }

    override public class func allowsReverseTransformation() -> Bool {
        return true
    }

    override public class func transformedValueClass() -> AnyClass {
        return ValueType.self
    }

    override public func transformedValue(_ value: Any?) -> Any? {
        guard let value else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
    }

    override public func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: ValueType.self, from: data)
    }
}
