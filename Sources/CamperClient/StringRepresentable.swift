import Camper

@StringRepresentable
public enum TestEnum {
    case one // Comment
    case two
    case three
}

@StringRepresentable
public enum SecondEnum {
    case one(TestEnum) // Comment
    case two
    case three(TestEnum?)
}

/// The documented shape: a plain value after the dot.
///
/// This is what the macro's own doc comment always promised and what its expansion could not
/// build — an associated `Int` was asked for a `rawValue` it does not have. It stands here so
/// the next change to the macro has to keep it compiling.
/// One value, and only one: the encoding's single degree of freedom is the tail, so exactly one
/// value may itself contain a dot. A second is refused rather than half-encoded — only the first
/// was ever read, so the rest went out and never came back.
@StringRepresentable
public enum Route {
    case home // "home"
    case settings(id: Int) // "settings.42"
    case note(text: String) // "note.whatever.was.typed"
    case profile(name: String?) // "profile" or "profile.john"
}
