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
