/// Generates static `Logger` properties from a nested `Categories` enum.
///
/// Each case in `Categories` becomes a `static let` logger with the corresponding category name.
///
/// - Parameter subsystem: The subsystem identifier. Defaults to the enum name
///   (with "LoggersCollection" or "Loggers" suffix stripped).
///
///     @LoggersCollection("com.example.app")
///     enum Loggers {
///         enum Categories {
///             case network
///             case database
///         }
///     }
///     // Generates:
///     // static let network = Logger(subsystem: "com.example.app", category: "Network")
///     // static let database = Logger(subsystem: "com.example.app", category: "Database")
@attached(member, names: arbitrary)
public macro LoggersCollection(_ subsystem: String = "") = #externalMacro(module: "CamperMacros", type: "LoggersCollectionMacro")
