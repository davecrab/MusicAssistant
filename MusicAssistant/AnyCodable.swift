import Foundation

enum AnyCodable: Codable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Int.self) { self = .int(value); return }
        if let value = try? container.decode(Double.self) { self = .double(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([AnyCodable].self) { self = .array(value); return }
        if let value = try? container.decode([String: AnyCodable].self) { self = .object(value); return }
        throw DecodingError.typeMismatch(
            AnyCodable.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }

    var stringValue: String? {
        switch self {
        case let .string(value): value
        default: nil
        }
    }
}

struct AnyDecodableObject: Decodable {
    let raw: [String: AnyCodable]
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        raw = (try? container.decode([String: AnyCodable].self)) ?? [:]
    }
}

