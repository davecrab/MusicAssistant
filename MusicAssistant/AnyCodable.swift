import Foundation

enum AnyCodable: Codable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([AnyCodable].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode([String: AnyCodable].self) {
            self = .object(value)
            return
        }
        throw DecodingError.typeMismatch(
            AnyCodable.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    // MARK: - Convenience Initializers

    init(_ value: Bool) {
        self = .bool(value)
    }

    init(_ value: Int) {
        self = .int(value)
    }

    init(_ value: Double) {
        self = .double(value)
    }

    init(_ value: String) {
        self = .string(value)
    }

    init(_ value: [AnyCodable]) {
        self = .array(value)
    }

    init(_ value: [String: AnyCodable]) {
        self = .object(value)
    }

    init(_ value: [String: Any]) {
        var dict: [String: AnyCodable] = [:]
        for (key, val) in value {
            dict[key] = AnyCodable(any: val)
        }
        self = .object(dict)
    }

    init(_ value: [Any]) {
        self = .array(value.map { AnyCodable(any: $0) })
    }

    init(any value: Any?) {
        guard let value = value else {
            self = .null
            return
        }

        switch value {
        case let bool as Bool:
            self = .bool(bool)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let string as String:
            self = .string(string)
        case let array as [Any]:
            self = .array(array.map { AnyCodable(any: $0) })
        case let dict as [String: Any]:
            var converted: [String: AnyCodable] = [:]
            for (key, val) in dict {
                converted[key] = AnyCodable(any: val)
            }
            self = .object(converted)
        case let codable as AnyCodable:
            self = codable
        default:
            // Try to convert to string as fallback
            self = .string(String(describing: value))
        }
    }

    // MARK: - Value Accessors

    var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return String(value)
        default: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        case .int(let value): return value != 0
        case .string(let value):
            let lower = value.lowercased()
            if lower == "true" || lower == "1" || lower == "yes" { return true }
            if lower == "false" || lower == "0" || lower == "no" { return false }
            return nil
        default: return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value): return Int(value)
        case .string(let value): return Int(value)
        case .bool(let value): return value ? 1 : 0
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let value): return value
        case .int(let value): return Double(value)
        case .string(let value): return Double(value)
        default: return nil
        }
    }

    var arrayValue: [AnyCodable]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    var objectValue: [String: AnyCodable]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }

    var isNull: Bool {
        if case .null = self {
            return true
        }
        return false
    }

    /// Returns the underlying Swift value
    var value: Any? {
        switch self {
        case .null: return nil
        case .bool(let value): return value
        case .int(let value): return value
        case .double(let value): return value
        case .string(let value): return value
        case .array(let value): return value.map { $0.value }
        case .object(let value): return value.mapValues { $0.value }
        }
    }

    // MARK: - Subscript Access

    subscript(key: String) -> AnyCodable? {
        get {
            if case .object(let dict) = self {
                return dict[key]
            }
            return nil
        }
    }

    subscript(index: Int) -> AnyCodable? {
        get {
            if case .array(let arr) = self, index >= 0, index < arr.count {
                return arr[index]
            }
            return nil
        }
    }
}

// MARK: - ExpressibleBy Protocols

extension AnyCodable: ExpressibleByNilLiteral {
    init(nilLiteral: ()) {
        self = .null
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: AnyCodable...) {
        self = .array(elements)
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, AnyCodable)...) {
        var dict: [String: AnyCodable] = [:]
        for (key, value) in elements {
            dict[key] = value
        }
        self = .object(dict)
    }
}

// MARK: - CustomStringConvertible

extension AnyCodable: CustomStringConvertible {
    var description: String {
        switch self {
        case .null: return "null"
        case .bool(let value): return String(value)
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .string(let value): return "\"\(value)\""
        case .array(let value): return "[\(value.map { $0.description }.joined(separator: ", "))]"
        case .object(let value):
            let pairs = value.map { "\"\($0)\": \($1.description)" }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

// MARK: - Helper for Raw Object Decoding

struct AnyDecodableObject: Decodable {
    let raw: [String: AnyCodable]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        raw = (try? container.decode([String: AnyCodable].self)) ?? [:]
    }
}
