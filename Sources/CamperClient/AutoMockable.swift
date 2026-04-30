import Camper
import Foundation

@AutoMockable
protocol AuthRepository {
    var isLoggedIn: Bool { get }
    var currentUser: String? { get }

    func login(email: String, password: String) async throws
    func logout() async
    func refresh() throws -> String
}

@AutoMockable
protocol AnalyticsTracker {
    func track(event: String, source: String)
    func flush()
}

@AutoMockable
public protocol PublicAPIService {
    var baseURL: URL { get set }
    func fetch(path: String) async throws -> Data
}

func checkAutoMockable() {
    let auth = AuthRepositoryMock()
    auth.underlyingIsLoggedIn = false
    auth.currentUser = "trail.runner"
    auth.refreshThrowableError = nil
    auth.refreshReturnValue = "token"

    let analytics = AnalyticsTrackerMock()
    // Multi-param mock methods record via ReceivedArguments / ReceivedInvocations.
    analytics.track(event: "viewed", source: "home")
    _ = analytics.trackEventStringSourceStringReceivedInvocations

    let api = PublicAPIServiceMock()
    api.underlyingBaseURL = URL(string: "https://example.com")!

    _ = (auth, analytics, api)
}
