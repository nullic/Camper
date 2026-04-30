import Foundation

public final class JSONValueTransformer<ValueType: Codable & NSObject>: ValueTransformer {
    public static var name: NSValueTransformerName { NSValueTransformerName(rawValue: "JSONValueTransformer<\(ValueType.self)>") }

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
        guard let value = value as? ValueType else { return nil }
        return try? JSONEncoder.base.encode(value) as NSData
    }

    override public func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder.base.decode(ValueType.self, from: data)
    }
}
