import Foundation

/// Events sent from the OpenAI Realtime API server
public enum ServerEvent: Sendable {
    case error(Error)
    case sessionCreated(Session)
    case sessionUpdated(Session)
    case conversationCreated(String)
    case conversationItemCreated(Item)
    case conversationItemDeleted(String)
    case conversationItemTruncated(itemId: String, contentIndex: Int, audioEndMs: Int)
    case conversationItemInputAudioTranscriptionCompleted(itemId: String, transcript: String)
    case conversationItemInputAudioTranscriptionFailed(itemId: String, error: Error)
    case responseCreated(Response)
    case responseDone(Response)
    case responseOutputItemAdded(itemId: String)
    case responseAudioTranscriptDelta(itemId: String, contentIndex: Int, delta: String)
    case responseAudioTranscriptDone(itemId: String, contentIndex: Int, transcript: String)
    case responseTextDelta(itemId: String, contentIndex: Int, delta: String)
    case responseTextDone(itemId: String, contentIndex: Int, text: String)
    case responseContentPartAdded(itemId: String, contentIndex: Int)
    case responseContentPartDone(itemId: String, contentIndex: Int)
    case responseAudioDone(itemId: String, contentIndex: Int)
    case responseOutputItemDone(itemId: String)
    case inputAudioBufferCommitted
    case inputAudioBufferCleared
    case inputAudioBufferSpeechStarted
    case inputAudioBufferSpeechStopped
    case outputAudioBufferStarted
    case outputAudioBufferStopped
    case outputAudioBufferCleared
    case rateLimitsUpdated([RateLimit])
    case unknown(String)

    public struct Error: Swift.Error, Codable, Sendable {
        public let type: String
        public let code: String?
        public let message: String
        public let param: String?

        public init(type: String, code: String? = nil, message: String, param: String? = nil) {
            self.type = type
            self.code = code
            self.message = message
            self.param = param
        }
    }

    public struct Response: Codable, Sendable {
        public let id: String
        public let status: Status?
        public let output: [Item]?

        public enum Status: String, Codable, Sendable {
            case completed
            case failed
            case cancelled
            case incomplete
            case inProgress = "in_progress"
        }
    }

    public struct Session: Codable, Sendable {
        public var instructions: String?
        public var voice: Voice?
        public var inputAudioTranscription: InputAudioTranscription?
        public var turnDetection: TurnDetection?

        public enum Voice: String, Codable, Sendable {
            case alloy, ash, ballad, coral, echo, sage, shimmer, verse
        }

        public struct InputAudioTranscription: Codable, Sendable {
            public var model: String?
            public var language: String?
        }

        public struct TurnDetection: Codable, Sendable {
            public var type: String?
            public var threshold: Double?
            public var prefixPaddingMs: Int?
            public var silenceDurationMs: Int?
        }
    }

    public struct RateLimit: Codable, Sendable {
        public let name: String
        public let limit: Int
        public let remaining: Int
        public let resetSeconds: Double

        enum CodingKeys: String, CodingKey {
            case name
            case limit
            case remaining
            case resetSeconds = "reset_seconds"
        }
    }
}

extension ServerEvent {
    /// Decodes a server event from JSON data with lenient parsing
    public static func decode(from data: Data) -> ServerEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String else {
            return nil
        }

        do {
            switch eventType {
            case "error":
                if let errorData = json["error"] as? [String: Any],
                   let error = try? decodeError(from: errorData) {
                    return .error(error)
                } else {
                    // Error might be at the top level
                    let error = try decodeError(from: json)
                    return .error(error)
                }

            case "session.created", "session.updated":
                if let sessionData = json["session"] as? [String: Any],
                   let session = try? decodeSession(from: sessionData) {
                    return eventType == "session.created" ? .sessionCreated(session) : .sessionUpdated(session)
                }

            case "conversation.created":
                if let conversationData = json["conversation"] as? [String: Any],
                   let id = conversationData["id"] as? String {
                    return .conversationCreated(id)
                }

            case "conversation.item.created":
                if let itemData = json["item"] as? [String: Any] {
                    do {
                        let itemJson = try JSONSerialization.data(withJSONObject: itemData)
                        let item = try JSONDecoder().decode(Item.self, from: itemJson)
                        return .conversationItemCreated(item)
                    } catch {
                        print("[ServerEvent] Failed to decode conversation.item.created: \(error)")
                        if let prettyData = try? JSONSerialization.data(withJSONObject: itemData, options: .prettyPrinted),
                           let jsonString = String(data: prettyData, encoding: .utf8) {
                            print("[ServerEvent] Item JSON: \(jsonString)")
                        }
                    }
                }
                return .unknown(eventType)

            case "conversation.item.deleted":
                if let itemId = json["item_id"] as? String {
                    return .conversationItemDeleted(itemId)
                }

            case "conversation.item.truncated":
                if let itemId = json["item_id"] as? String,
                   let contentIndex = json["content_index"] as? Int,
                   let audioEndMs = json["audio_end_ms"] as? Int {
                    return .conversationItemTruncated(itemId: itemId, contentIndex: contentIndex, audioEndMs: audioEndMs)
                }

            case "conversation.item.input_audio_transcription.completed":
                if let itemId = json["item_id"] as? String,
                   let transcript = json["transcript"] as? String {
                    return .conversationItemInputAudioTranscriptionCompleted(
                        itemId: itemId,
                        transcript: transcript
                    )
                } else {
                    print("[ServerEvent] Failed to decode input_audio_transcription.completed")
                    print("[ServerEvent] item_id: \(json["item_id"] ?? "nil"), transcript: \(json["transcript"] ?? "nil")")
                    return .unknown(eventType)
                }

            case "conversation.item.input_audio_transcription.failed":
                if let itemId = json["item_id"] as? String,
                   let errorData = json["error"] as? [String: Any],
                   let error = try? decodeError(from: errorData) {
                    return .conversationItemInputAudioTranscriptionFailed(itemId: itemId, error: error)
                }

            case "response.created", "response.done":
                if let responseData = json["response"] as? [String: Any],
                   let response = try? decodeResponse(from: responseData) {
                    return eventType == "response.created" ? .responseCreated(response) : .responseDone(response)
                }
                // Fallback: if response field is missing but we have required fields at top level
                if let id = json["response_id"] as? String ?? json["id"] as? String {
                    let response = Response(id: id, status: nil, output: nil)
                    return eventType == "response.created" ? .responseCreated(response) : .responseDone(response)
                }

            case "response.output_item.added":
                if let itemId = json["item_id"] as? String {
                    return .responseOutputItemAdded(itemId: itemId)
                }

            case "response.audio_transcript.delta":
                return decodeContentUpdate(from: json, isDelta: true, isAudio: true)

            case "response.audio_transcript.done":
                return decodeContentUpdate(from: json, isDelta: false, isAudio: true)

            case "response.text.delta":
                return decodeContentUpdate(from: json, isDelta: true, isAudio: false)

            case "response.text.done":
                return decodeContentUpdate(from: json, isDelta: false, isAudio: false)

            case "response.content_part.added":
                if let itemId = json["item_id"] as? String,
                   let contentIndex = json["content_index"] as? Int {
                    return .responseContentPartAdded(itemId: itemId, contentIndex: contentIndex)
                }

            case "response.content_part.done":
                if let itemId = json["item_id"] as? String,
                   let contentIndex = json["content_index"] as? Int {
                    return .responseContentPartDone(itemId: itemId, contentIndex: contentIndex)
                }

            case "response.audio.done":
                if let itemId = json["item_id"] as? String,
                   let contentIndex = json["content_index"] as? Int {
                    return .responseAudioDone(itemId: itemId, contentIndex: contentIndex)
                }

            case "response.output_item.done":
                if let itemId = json["item_id"] as? String {
                    return .responseOutputItemDone(itemId: itemId)
                }
                return .unknown(eventType)

            case "input_audio_buffer.committed":
                return .inputAudioBufferCommitted

            case "input_audio_buffer.cleared":
                return .inputAudioBufferCleared

            case "input_audio_buffer.speech_started":
                return .inputAudioBufferSpeechStarted

            case "input_audio_buffer.speech_stopped":
                return .inputAudioBufferSpeechStopped

            case "output_audio_buffer.started":
                return .outputAudioBufferStarted

            case "output_audio_buffer.stopped":
                return .outputAudioBufferStopped

            case "output_audio_buffer.cleared":
                return .outputAudioBufferCleared

            case "rate_limits.updated":
                if let limitsData = json["rate_limits"] as? [[String: Any]] {
                    let limits = limitsData.compactMap { try? decodeRateLimit(from: $0) }
                    return .rateLimitsUpdated(limits)
                }

            default:
                return .unknown(eventType)
            }
        } catch {
            return .unknown(eventType)
        }

        return .unknown(eventType)
    }

    private static func decodeError(from json: [String: Any]) throws -> Error {
        guard let message = json["message"] as? String else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing error message"))
        }
        return Error(
            type: json["type"] as? String ?? "unknown",
            code: json["code"] as? String,
            message: message,
            param: json["param"] as? String
        )
    }

    private static func decodeSession(from json: [String: Any]) throws -> Session {
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Session.self, from: data)
    }

    private static func decodeResponse(from json: [String: Any]) throws -> Response {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func decodeRateLimit(from json: [String: Any]) throws -> RateLimit {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(RateLimit.self, from: data)
    }

    private static func decodeContentUpdate(from json: [String: Any], isDelta: Bool, isAudio: Bool) -> ServerEvent? {
        guard let itemId = json["item_id"] as? String,
              let contentIndex = json["content_index"] as? Int else {
            return nil
        }

        if isDelta {
            guard let delta = json["delta"] as? String else { return nil }
            return isAudio ?
                .responseAudioTranscriptDelta(itemId: itemId, contentIndex: contentIndex, delta: delta) :
                .responseTextDelta(itemId: itemId, contentIndex: contentIndex, delta: delta)
        } else {
            let key = isAudio ? "transcript" : "text"
            guard let content = json[key] as? String else { return nil }
            return isAudio ?
                .responseAudioTranscriptDone(itemId: itemId, contentIndex: contentIndex, transcript: content) :
                .responseTextDone(itemId: itemId, contentIndex: contentIndex, text: content)
        }
    }
}
