import Foundation

extension StringProtocol {
    var firstUppercased: String { prefix(1).uppercased() + dropFirst() }
    var firstCapitalized: String { prefix(1).capitalized + dropFirst() }

    var asInputModel: String { self + ".InputModel" }
    var asInputEnum: String { firstCapitalized + "Input" }
}
