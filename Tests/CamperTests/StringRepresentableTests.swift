import Camper
import Foundation
import Testing

/// The macro used through the front door, so the code it writes has to compile.
///
/// `CamperMacrosTests` asserts the expansion as text, which is the right test for the shape it
/// emits and no test at all for whether that shape builds: the documented `settings(id: Int)`
/// case expanded to `value.rawValue` and `Int(rawValue:)`, neither of which exists, and the
/// suite stayed green for as long as nobody used it.
@Suite("@StringRepresentable")
struct StringRepresentableTests {
    @StringRepresentable
    enum Route: Equatable, Codable {
        case home
        case settings(id: Int)
        case profile(name: String?)
        case note(text: String)
    }

    @Test("a case with no value is its own name")
    func plainCase() throws {
        #expect(Route.home.rawValue == "home")
        #expect(Route(rawValue: "home") == .home)
    }

    @Test("an Int rides after the dot and comes back an Int")
    func intValue() throws {
        #expect(Route.settings(id: 42).rawValue == "settings.42")
        #expect(Route(rawValue: "settings.42") == .settings(id: 42))
        #expect(Route(rawValue: "settings.not-a-number") == nil)
    }

    @Test("a String rides after the dot, dots in it included")
    func stringValue() throws {
        #expect(Route.note(text: "a.b.c").rawValue == "note.a.b.c")
        #expect(Route(rawValue: "note.a.b.c") == .note(text: "a.b.c"))
    }

    @Test("an optional value omits the suffix when nil")
    func optionalValue() throws {
        #expect(Route.profile(name: nil).rawValue == "profile")
        #expect(Route.profile(name: "john").rawValue == "profile.john")
        #expect(Route(rawValue: "profile") == .profile(name: nil))
        #expect(Route(rawValue: "profile.john") == .profile(name: "john"))
    }

    /// The opt-in spelling, for an enum that rides in a snake_case document.
    @StringRepresentable(.snakeCase)
    enum Trigger: Equatable, Codable {
        case scenarioStart
        case countdownStep(step: Int)
        case allCluesRevealed
    }

    @Test("the snake_case spelling is asked for, never assumed")
    func snakeCaseNaming() throws {
        #expect(Trigger.scenarioStart.rawValue == "scenario_start")
        #expect(Trigger.allCluesRevealed.rawValue == "all_clues_revealed")
        #expect(Trigger.countdownStep(step: 2).rawValue == "countdown_step.2")
        #expect(Trigger(rawValue: "countdown_step.2") == .countdownStep(step: 2))
        #expect(Trigger(rawValue: "scenarioStart") == nil, "the case's own name is not the spelling asked for")
    }

    @Test("the default spelling is the case's own name, so stored values keep reading")
    func defaultNamingIsUnchanged() throws {
        #expect(Route.home.rawValue == "home")
        #expect(Route.settings(id: 1).rawValue == "settings.1")
    }

    @Test("a name no case answers to is nil, not a crash")
    func unknownCase() throws {
        #expect(Route(rawValue: "nowhere") == nil)
        #expect(Route(rawValue: "") == nil)
    }

    /// What the conformance buys: `Codable` rides on `RawRepresentable`, so a case with a
    /// value needs no hand-written coder.
    @Test("the whole enum codes as one string")
    func codesAsOneString() throws {
        let data = try JSONEncoder().encode(["route": Route.settings(id: 7)])
        #expect(String(decoding: data, as: UTF8.self) == #"{"route":"settings.7"}"#)
        let back = try JSONDecoder().decode([String: Route].self, from: data)
        #expect(back["route"] == .settings(id: 7))
    }
}
