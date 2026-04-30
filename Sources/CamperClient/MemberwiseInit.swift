import Camper
import Foundation

@MemberwiseInit
public struct UserProfile {
    public let name: String
    public let bio: String?
    public let avatarURL: URL?
    public let isAdmin: Bool
}

@MemberwiseInit
struct CacheEntry<Value> {
    let key: String
    let value: Value
    let expiresAt: Date?
}

func checkMemberwiseInit() {
    let profile = UserProfile(name: "Trail Runner", isAdmin: false)
    _ = profile

    let entry = CacheEntry(key: "k", value: 42, expiresAt: nil)
    _ = entry
}
