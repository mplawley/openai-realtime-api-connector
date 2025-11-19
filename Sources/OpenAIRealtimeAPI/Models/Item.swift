import Foundation

/// Represents different types of conversation items in the Realtime API
public enum Item: Identifiable, Codable, Sendable {
    case message(Message)
    case functionCall(FunctionCall)
    case functionCallOutput(FunctionCallOutput)

    public var id: String {
        switch self {
        case .message(let message): return message.id
        case .functionCall(let call): return call.id
        case .functionCallOutput(let output): return output.id
        }
    }

    public struct Message: Identifiable, Codable, Sendable {
        public let id: String
        public var role: Role
        public var content: [Content]

        public enum Role: String, Codable, Sendable {
            case user
            case assistant
            case system
        }

        public enum Content: Codable, Sendable {
            case text(String)
            case audio(Audio)
            case inputText(String)
            case inputAudio(Audio)

            public var displayText: String? {
                switch self {
                case .text(let text): return text
                case .inputText(let text): return text
                case .audio(let audio): return audio.transcript
                case .inputAudio(let audio): return audio.transcript
                }
            }
        }

        public struct Audio: Codable, Sendable {
            public var data: Data?
            public var transcript: String?

            public init(data: Data? = nil, transcript: String? = nil) {
                self.data = data
                self.transcript = transcript
            }
        }

        public init(id: String, role: Role, content: [Content]) {
            self.id = id
            self.role = role
            self.content = content
        }

        enum CodingKeys: String, CodingKey {
            case type, id, role, content
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            role = try container.decode(Role.self, forKey: .role)
            content = try container.decode([Content].self, forKey: .content)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("message", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
        }
    }

    public struct FunctionCall: Identifiable, Codable, Sendable {
        public let id: String
        public var callId: String
        public var name: String
        public var arguments: String

        public init(id: String, callId: String, name: String, arguments: String) {
            self.id = id
            self.callId = callId
            self.name = name
            self.arguments = arguments
        }

        enum CodingKeys: String, CodingKey {
            case type, id, callId = "call_id", name, arguments
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            callId = try container.decode(String.self, forKey: .callId)
            name = try container.decode(String.self, forKey: .name)
            arguments = try container.decode(String.self, forKey: .arguments)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("function_call", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(callId, forKey: .callId)
            try container.encode(name, forKey: .name)
            try container.encode(arguments, forKey: .arguments)
        }
    }

    public struct FunctionCallOutput: Identifiable, Codable, Sendable {
        public let id: String
        public var callId: String
        public var output: String

        public init(id: String, callId: String, output: String) {
            self.id = id
            self.callId = callId
            self.output = output
        }

        enum CodingKeys: String, CodingKey {
            case type, id, callId = "call_id", output
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            callId = try container.decode(String.self, forKey: .callId)
            output = try container.decode(String.self, forKey: .output)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("function_call_output", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(callId, forKey: .callId)
            try container.encode(output, forKey: .output)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "message":
            self = try .message(Message(from: decoder))
        case "function_call":
            self = try .functionCall(FunctionCall(from: decoder))
        case "function_call_output":
            self = try .functionCallOutput(FunctionCallOutput(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown item type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .message(let message):
            try message.encode(to: encoder)
        case .functionCall(let call):
            try call.encode(to: encoder)
        case .functionCallOutput(let output):
            try output.encode(to: encoder)
        }
    }
}

extension Item: Equatable {
    public static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.id == rhs.id
    }
}

extension Item.Message: Equatable {}
extension Item.Message.Content: Equatable {}
extension Item.Message.Audio: Equatable {}
extension Item.FunctionCall: Equatable {}
extension Item.FunctionCallOutput: Equatable {}
