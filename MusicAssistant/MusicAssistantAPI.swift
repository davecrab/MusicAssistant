import Foundation

struct MusicAssistantAPI {
    var baseURL: URL
    var token: String?

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        // Note: We do NOT use .convertFromSnakeCase because all models
        // have explicit CodingKeys that specify the JSON key names.
        // Using convertFromSnakeCase with explicit CodingKeys causes
        // double-conversion issues where keys can't be found.
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        // Note: We do NOT use .convertToSnakeCase because API commands
        // are sent with explicit key names in the args dictionary.
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

            private enum CodingKeys: String, CodingKey {
                case providerId = "provider_id"
                case credentials
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
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Log raw response for debugging
            let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode as UTF-8"
            print("DEBUG API Error for command '\(command)':")
            print("DEBUG Response (first 2000 chars): \(String(rawResponse.prefix(2000)))")
            print("DEBUG Decoding error: \(error)")
            throw error
        }
    }

    func executeOptional<T: Decodable>(
        command: String,
        args: [String: AnyCodable],
        as: T.Type
    ) async throws -> T? {
        let body = APICommandBody(command: command, args: args)
        let data = try await request(
            path: "/api", method: "POST", body: try encoder.encode(body), requiresAuth: true)
        do {
            return try decoder.decode(T?.self, from: data)
        } catch {
            // Log raw response for debugging
            let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode as UTF-8"
            print("DEBUG API Error for command '\(command)':")
            print("DEBUG Response (first 2000 chars): \(String(rawResponse.prefix(2000)))")
            print("DEBUG Decoding error: \(error)")
            throw error
        }
    }

    func executeVoid(command: String, args: [String: AnyCodable]) async throws {
        let body = APICommandBody(command: command, args: args)
        _ = try await request(
            path: "/api", method: "POST", body: try encoder.encode(body), requiresAuth: true)
    }

    // MARK: - Provider Manifest Methods

    func getProviderManifests() async throws -> [String: MAProviderManifest] {
        // API returns an array, we convert to dictionary keyed by domain
        let manifests = try await execute(
            command: "providers/manifests",
            args: [:],
            as: [MAProviderManifest].self
        )
        return Dictionary(uniqueKeysWithValues: manifests.map { ($0.domain, $0) })
    }

    // MARK: - Provider Config Methods

    func getProviderConfigs(
        providerType: MAProviderType? = nil,
        providerDomain: String? = nil
    ) async throws -> [MAProviderConfig] {
        var args: [String: AnyCodable] = [:]
        if let providerType {
            args["provider_type"] = .string(providerType.rawValue)
        }
        if let providerDomain {
            args["provider_domain"] = .string(providerDomain)
        }
        return try await execute(
            command: "config/providers",
            args: args,
            as: [MAProviderConfig].self
        )
    }

    func getProviderConfig(instanceID: String) async throws -> MAProviderConfig {
        return try await execute(
            command: "config/providers/get",
            args: ["instance_id": .string(instanceID)],
            as: MAProviderConfig.self
        )
    }

    func getProviderConfigEntries(
        providerDomain: String,
        instanceID: String? = nil,
        action: String? = nil,
        values: [String: AnyCodable]? = nil
    ) async throws -> [MAConfigEntry] {
        var args: [String: AnyCodable] = [
            "provider_domain": .string(providerDomain)
        ]
        if let instanceID {
            args["instance_id"] = .string(instanceID)
        }
        if let action {
            args["action"] = .string(action)
        }
        if let values {
            args["values"] = .object(values)
        }
        return try await execute(
            command: "config/providers/get_entries",
            args: args,
            as: [MAConfigEntry].self
        )
    }

    func saveProviderConfig(
        providerDomain: String,
        values: [String: AnyCodable],
        instanceID: String? = nil
    ) async throws -> MAProviderConfig {
        var args: [String: AnyCodable] = [
            "provider_domain": .string(providerDomain),
            "values": .object(values),
        ]
        if let instanceID {
            args["instance_id"] = .string(instanceID)
        }
        return try await execute(
            command: "config/providers/save",
            args: args,
            as: MAProviderConfig.self
        )
    }

    /// Save provider config without expecting a parsed response.
    /// Use this when you don't need the returned config and want to avoid parsing errors.
    func saveProviderConfigVoid(
        providerDomain: String,
        values: [String: AnyCodable],
        instanceID: String? = nil
    ) async throws {
        var args: [String: AnyCodable] = [
            "provider_domain": .string(providerDomain),
            "values": .object(values),
        ]
        if let instanceID {
            args["instance_id"] = .string(instanceID)
        }
        try await executeVoid(
            command: "config/providers/save",
            args: args
        )
    }

    func removeProviderConfig(instanceID: String) async throws {
        try await executeVoid(
            command: "config/providers/remove",
            args: ["instance_id": .string(instanceID)]
        )
    }

    func reloadProvider(instanceID: String) async throws {
        try await executeVoid(
            command: "config/providers/reload",
            args: ["instance_id": .string(instanceID)]
        )
    }

    // MARK: - Browse Methods

    /// Browse music providers. Returns a list of browse items (folders, tracks, etc.)
    /// - Parameter path: Optional path to browse. If nil, returns root level items.
    func browse(path: String? = nil) async throws -> [MABrowseItem] {
        var args: [String: AnyCodable] = [:]
        if let path {
            args["path"] = .string(path)
        }
        return try await execute(
            command: "music/browse",
            args: args,
            as: [MABrowseItem].self
        )
    }

    /// Get a specific item by URI
    func getItem(uri: String) async throws -> MABrowseItem? {
        return try await executeOptional(
            command: "music/get_item_by_uri",
            args: ["uri": .string(uri)],
            as: MABrowseItem.self
        )
    }

    // MARK: - Player Config Methods

    func getPlayerConfigs(provider: String? = nil) async throws -> [MAPlayerConfig] {
        var args: [String: AnyCodable] = [:]
        if let provider {
            args["provider"] = .string(provider)
        }
        return try await execute(
            command: "config/players",
            args: args,
            as: [MAPlayerConfig].self
        )
    }

    func getPlayerConfig(playerID: String) async throws -> MAPlayerConfig {
        return try await execute(
            command: "config/players/get",
            args: ["player_id": .string(playerID)],
            as: MAPlayerConfig.self
        )
    }

    func getPlayerConfigEntries(
        playerID: String,
        action: String? = nil,
        values: [String: AnyCodable]? = nil
    ) async throws -> [MAConfigEntry] {
        var args: [String: AnyCodable] = [
            "player_id": .string(playerID)
        ]
        if let action {
            args["action"] = .string(action)
        }
        if let values {
            args["values"] = .object(values)
        }
        return try await execute(
            command: "config/players/get_entries",
            args: args,
            as: [MAConfigEntry].self
        )
    }

    func savePlayerConfig(
        playerID: String,
        values: [String: AnyCodable]
    ) async throws -> MAPlayerConfig {
        return try await execute(
            command: "config/players/save",
            args: [
                "player_id": .string(playerID),
                "values": .object(values),
            ],
            as: MAPlayerConfig.self
        )
    }

    func removePlayerConfig(playerID: String) async throws {
        try await executeVoid(
            command: "config/players/remove",
            args: ["player_id": .string(playerID)]
        )
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
