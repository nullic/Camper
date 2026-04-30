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
    func track(event: String, properties: [String: String])
    func observe(values: [String])
    func flush()
}

@AutoMockable
public protocol PublicAPIService {
    var baseURL: URL { get set }
    func fetch(path: String) async throws -> Data
    func upload(attachments: [String]?) async throws
    func intersect(tags: Set<String>) -> Set<String>
}

func checkAutoMockable() {
    let auth = AuthRepositoryMock()
    auth.underlyingIsLoggedIn = false
    auth.currentUser = "trail.runner"
    auth.refreshThrowableError = nil
    auth.refreshReturnValue = "token"

    let analytics = AnalyticsTrackerMock()
    // Multi-param mock methods record via ReceivedArguments / ReceivedInvocations.
    analytics.track(event: "viewed", properties: ["source": "home"])
    _ = analytics.trackEventStringPropertiesStringStringReceivedInvocations

    analytics.observe(values: ["a", "b"])
    _ = analytics.observeValuesStringsReceivedValues

    let api = PublicAPIServiceMock()
    api.underlyingBaseURL = URL(string: "https://example.com")!

    // Optional-array gets the `s` suffix (unwrapped through OptionalTypeSyntax).
    _ = api.uploadAttachmentsStringsCallsCount

    // Set<T> is neither Array nor Optional, so no `s` suffix.
    _ = api.intersectTagsSetStringReturnValue

    _ = (auth, analytics, api)
}
