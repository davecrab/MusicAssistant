import Foundation

struct MusicAssistantAPI {
    var baseURL: URL
    var token: String?

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    func authProviders() async throws -> [AuthProvider] {
        struct Response: Decodable {
            let providers: [AnyDecodableObject]
        }
        let data = try await request(
            path: "/auth/providers", method: "GET", body: nil, requiresAuth: false)
        let response = try decoder.decode(Response.self, from: data)
        return response.providers.map { AuthProvider(from: $0.raw) }.sorted { $0.name < $1.name }
    }

    func login(providerID: String, username: String, password: String) async throws -> LoginResult {
        struct Body: Encodable {
            let providerId: String
            let credentials: Credentials
            struct Credentials: Encodable {
                let username: String
                let password: String
            }
        }
        let body = Body(
            providerId: providerID, credentials: .init(username: username, password: password))
        let data = try await request(
            path: "/auth/login", method: "POST", body: try encoder.encode(body), requiresAuth: false
        )
        return try decoder.decode(LoginResult.self, from: data)
    }

    func execute<T: Decodable>(command: String, args: [String: AnyCodable], as: T.Type) async throws
        -> T
    {
        let body = APICommandBody(command: command, args: args)
        let data = try await request(
            path: "/api", method: "POST", body: try encoder.encode(body), requiresAuth: true)
        return try decoder.decode(T.self, from: data)
    }

    func executeVoid(command: String, args: [String: AnyCodable]) async throws {
        _ = try await execute(command: command, args: args, as: EmptyResponse.self)
    }

    private func request(path: String, method: String, body: Data?, requiresAuth: Bool) async throws
        -> Data
    {
        var url = baseURL
        url.append(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if requiresAuth, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return data }
        if (200..<300).contains(http.statusCode) { return data }
        throw APIError(httpStatus: http.statusCode, body: data)
    }
}

struct APICommandBody: Encodable {
    let command: String
    let args: [String: AnyCodable]
}

struct EmptyResponse: Decodable {}

struct LoginResult: Decodable {
    let success: Bool?
    let token: String
}

struct AuthProvider: Identifiable, Hashable {
    var id: String
    var name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(from raw: [String: AnyCodable]) {
        let id = raw["id"]?.stringValue ?? raw["provider_id"]?.stringValue ?? "builtin"
        let name = raw["name"]?.stringValue ?? raw["display_name"]?.stringValue ?? id
        self.init(id: id, name: name)
    }
}

struct APIError: LocalizedError {
    let httpStatus: Int
    let body: Data

    var errorDescription: String? {
        let message = String(data: body, encoding: .utf8)?.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if let message, !message.isEmpty {
            return "Server error (\(httpStatus)): \(message)"
        }
        return "Server error (\(httpStatus))"
    }
}
