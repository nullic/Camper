import Camper
import OSLog

@LoggersCollection("Subsystem")
enum Loggers {
    enum Categories {
        case general
        case common
    }
}

enum MyLogger: String, Camper.Logger {
    var subsystem: String { "Subsystem" }
    case general
}

func checkLoggers() {
    Loggers.general.debug("Test")
    Loggers.common.warning("Test")

    LoggerConfigurator.configure()
    MyLogger.general.error("Test2")
}
