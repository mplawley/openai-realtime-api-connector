import Foundation

/// Events sent from the iOS Client to the OpenAI Realtime API server
public enum ClientEvent: Codable, Sendable {
    case updateSession(SessionUpdate)
    case appendInputAudioBuffer(Data)
    case commitInputAudioBuffer
    case clearInputAudioBuffer
    case createResponse(ResponseConfig?)
    case truncateResponse(String, Int)
    case cancelResponse(String)

    public struct SessionUpdate: Codable, Sendable {
        public var instructions: String?
        public var voice: String?
        public var inputAudioTranscription: InputAudioTranscription?
        public var inputAudioNoiseReduction: InputAudioNoiseReduction?
        public var turnDetection: TurnDetection?

        public struct InputAudioTranscription: Codable, Sendable {
            public var model: String?
            public var language: String?

            public init(model: String? = nil, language: String? = nil) {
                self.model = model
                self.language = language
            }
        }

        public struct InputAudioNoiseReduction: Codable, Sendable {
            public var type: String

            public init(type: String) {
                self.type = type
            }

            /// For close-talking microphones such as headphones
            public static var nearField: InputAudioNoiseReduction {
                InputAudioNoiseReduction(type: "near_field")
            }

            /// For far-field microphones such as laptop or conference room microphones
            public static var farField: InputAudioNoiseReduction {
                InputAudioNoiseReduction(type: "far_field")
            }
        }

        public struct TurnDetection: Codable, Sendable {
            public var type: String
            public var threshold: Double?
            public var prefixPaddingMs: Int?
            public var silenceDurationMs: Int?
            public var createResponse: Bool?

            enum CodingKeys: String, CodingKey {
                case type
                case threshold
                case prefixPaddingMs = "prefix_padding_ms"
                case silenceDurationMs = "silence_duration_ms"
                case createResponse = "create_response"
            }

            public init(
                type: String,
                threshold: Double? = nil,
                prefixPaddingMs: Int? = nil,
                silenceDurationMs: Int? = nil,
                createResponse: Bool? = nil
            ) {
                self.type = type
                self.threshold = threshold
                self.prefixPaddingMs = prefixPaddingMs
                self.silenceDurationMs = silenceDurationMs
                self.createResponse = createResponse
            }

            public static func serverVad(
                threshold: Double? = 0.5,
                prefixPaddingMs: Int? = 300,
                silenceDurationMs: Int? = 500,
                createResponse: Bool = true
            ) -> TurnDetection {
                TurnDetection(
                    type: "server_vad",
                    threshold: threshold,
                    prefixPaddingMs: prefixPaddingMs,
                    silenceDurationMs: silenceDurationMs,
                    createResponse: createResponse
                )
            }
        }

        public init(
            instructions: String? = nil,
            voice: String? = nil,
            inputAudioTranscription: InputAudioTranscription? = nil,
            inputAudioNoiseReduction: InputAudioNoiseReduction? = nil,
            turnDetection: TurnDetection? = nil
        ) {
            self.instructions = instructions
            self.voice = voice
            self.inputAudioTranscription = inputAudioTranscription
            self.inputAudioNoiseReduction = inputAudioNoiseReduction
            self.turnDetection = turnDetection
        }
    }

    public struct ResponseConfig: Codable, Sendable {
        public var instructions: String?
        public var voice: String?
        public var temperature: Double?

        public init(instructions: String? = nil, voice: String? = nil, temperature: Double? = nil) {
            self.instructions = instructions
            self.voice = voice
            self.temperature = temperature
        }
    }

    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let json: [String: Any]

        switch self {
        case .updateSession(let update):
            let data = try encoder.encode(update)
            let sessionDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            json = ["type": "session.update", "session": sessionDict]

            // Debug: log session update
            if let debugData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let debugString = String(data: debugData, encoding: .utf8) {
                print("[ClientEvent] Sending session.update: \(debugString)")
            }

        case .appendInputAudioBuffer(let audioData):
            json = [
                "type": "input_audio_buffer.append",
                "audio": audioData.base64EncodedString()
            ]

        case .commitInputAudioBuffer:
            json = ["type": "input_audio_buffer.commit"]

        case .clearInputAudioBuffer:
            json = ["type": "input_audio_buffer.clear"]

        case .createResponse(let config):
            var dict: [String: Any] = ["type": "response.create"]
            if let config = config,
               let configData = try? encoder.encode(config),
               let configDict = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                dict["response"] = configDict
            }
            json = dict

        case .truncateResponse(let responseId, let audioMs):
            json = [
                "type": "response.truncate",
                "response_id": responseId,
                "audio_end_ms": audioMs
            ]

        case .cancelResponse(let responseId):
            json = [
                "type": "response.cancel",
                "response_id": responseId
            ]
        }

        return try JSONSerialization.data(withJSONObject: json)
    }

    public init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "ClientEvent decoding not supported")
        )
    }

    public func encode(to encoder: Encoder) throws {
        // Use the custom encode() method instead
        throw EncodingError.invalidValue(
            self,
            .init(codingPath: [], debugDescription: "Use encode() method instead")
        )
    }
}
