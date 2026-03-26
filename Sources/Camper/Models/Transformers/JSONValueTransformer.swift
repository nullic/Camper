import Foundation

public final class JSONValueTransformer<ValueType: Codable>: ValueTransformer {
    static var name: NSValueTransformerName { NSValueTransformerName(rawValue: "JSONValueTransformer<\(ValueType.self)>") }

    public static func register() {
        ValueTransformer.setValueTransformer(Self(), forName: name)
    }

    override public class func allowsReverseTransformation() -> Bool {
        return true
    }

    override public class func transformedValueClass() -> AnyClass {
        return ValueType.self as! AnyClass.Type
    }

    override public func transformedValue(_ value: Any?) -> Any? {
        guard let codable = value as? Codable else { return nil }
        return try! JSONEncoder.base.encode(codable) as NSData
    }

    override public func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try! JSONDecoder.base.decode(ValueType.self, from: data)
    }
}
