import Foundation

public actor KiwiVMClient {
    public struct Credentials: Hashable, Sendable {
        public let veid: String
        public let apiKey: String

        public init(veid: String, apiKey: String) {
            self.veid = veid
            self.apiKey = apiKey
        }
    }

    public enum ClientError: Error, LocalizedError {
        case invalidResponse
        case apiError(String)

        public var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "KiwiVM API returned an invalid response."
            case let .apiError(message):
                return message
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(baseURL: URL = AppConfiguration.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
    }

    public func getServiceInfo(credentials: Credentials) async throws -> ServiceInfoResponse {
        try await request("getServiceInfo", credentials: credentials)
    }

    public func getLiveServiceInfo(credentials: Credentials) async throws -> LiveServiceInfoResponse {
        try await request("getLiveServiceInfo", credentials: credentials)
    }

    public func getRawUsageStats(credentials: Credentials) async throws -> JSONValue {
        let data = try await requestData("getRawUsageStats", credentials: credentials)

        if let value = try? decoder.decode(JSONValue.self, from: data) {
            return value
        }

        if let error = try? decoder.decode(MutationResponse.self, from: data), error.error != 0 {
            throw ClientError.apiError(error.message ?? "KiwiVM getRawUsageStats failed.")
        }

        throw ClientError.invalidResponse
    }

    public func getRateLimitStatus(credentials: Credentials) async throws -> RateLimitStatusResponse {
        try await request("getRateLimitStatus", credentials: credentials)
    }

    public func start(credentials: Credentials) async throws {
        let response: MutationResponse = try await request("start", credentials: credentials)
        try validate(response)
    }

    public func stop(credentials: Credentials) async throws {
        let response: MutationResponse = try await request("stop", credentials: credentials)
        try validate(response)
    }

    public func restart(credentials: Credentials) async throws {
        let response: MutationResponse = try await request("restart", credentials: credentials)
        try validate(response)
    }

    private func validate(_ response: MutationResponse) throws {
        guard response.error == 0 else {
            throw ClientError.apiError(response.message ?? "KiwiVM mutation failed.")
        }
    }

    private func request<Response: Decodable>(
        _ path: String,
        credentials: Credentials
    ) async throws -> Response {
        let data = try await requestData(path, credentials: credentials)
        let decoded = try decoder.decode(Response.self, from: data)

        if let serviceResponse = decoded as? ServiceInfoResponse, serviceResponse.error != 0 {
            throw ClientError.apiError(serviceResponse.message ?? "KiwiVM getServiceInfo failed.")
        }

        if let mutationResponse = decoded as? MutationResponse, mutationResponse.error != 0 {
            throw ClientError.apiError(mutationResponse.message ?? "KiwiVM mutation failed.")
        }

        if let rateLimitResponse = decoded as? RateLimitStatusResponse, rateLimitResponse.error != 0 {
            throw ClientError.apiError("KiwiVM rate limit status request failed.")
        }

        return decoded
    }

    private func requestData(
        _ path: String,
        credentials: Credentials
    ) async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "veid", value: credentials.veid),
            URLQueryItem(name: "api_key", value: credentials.apiKey),
        ]

        guard let url = components?.url else {
            throw ClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
            throw ClientError.invalidResponse
        }
        return data
    }
}
