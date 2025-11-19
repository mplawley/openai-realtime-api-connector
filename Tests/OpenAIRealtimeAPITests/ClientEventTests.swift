import XCTest
@testable import OpenAIRealtimeAPI

final class ClientEventTests: XCTestCase {
    func testSessionUpdateEncoding() throws {
        var update = ClientEvent.SessionUpdate()
        update.instructions = "You are a helpful assistant"
        update.voice = "alloy"

        let event = ClientEvent.updateSession(update)
        let data = try event.encode()

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "session.update")

        let session = json?["session"] as? [String: Any]
        XCTAssertEqual(session?["instructions"] as? String, "You are a helpful assistant")
        XCTAssertEqual(session?["voice"] as? String, "alloy")
    }

    func testSessionUpdateWithTurnDetection() throws {
        var update = ClientEvent.SessionUpdate()
        update.turnDetection = .serverVad(
            threshold: 0.6,
            prefixPaddingMs: 300,
            silenceDurationMs: 500
        )

        let event = ClientEvent.updateSession(update)
        let data = try event.encode()

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let session = json?["session"] as? [String: Any]
        let turnDetection = session?["turn_detection"] as? [String: Any]

        XCTAssertEqual(turnDetection?["type"] as? String, "server_vad")
        XCTAssertEqual(turnDetection?["threshold"] as? Double, 0.6)
        XCTAssertEqual(turnDetection?["prefix_padding_ms"] as? Int, 300)
        XCTAssertEqual(turnDetection?["silence_duration_ms"] as? Int, 500)
        XCTAssertEqual(turnDetection?["create_response"] as? Bool, true)
    }

    func testSessionUpdateWithTranscription() throws {
        var update = ClientEvent.SessionUpdate()
        update.inputAudioTranscription = .init(model: "whisper-1", language: "en")

        let event = ClientEvent.updateSession(update)
        let data = try event.encode()

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let session = json?["session"] as? [String: Any]
        let transcription = session?["input_audio_transcription"] as? [String: Any]

        XCTAssertEqual(transcription?["model"] as? String, "whisper-1")
        XCTAssertEqual(transcription?["language"] as? String, "en")
    }

    func testAppendInputAudioBufferEncoding() throws {
        let audioData = Data([0x01, 0x02, 0x03, 0x04])
        let event = ClientEvent.appendInputAudioBuffer(audioData)
        let data = try event.encode()

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "input_audio_buffer.append")
        XCTAssertEqual(json?["audio"] as? String, audioData.base64EncodedString())
    }

    func testCommitInputAudioBufferEncoding() throws {
        let event = ClientEvent.commitInputAudioBuffer
        let data = try event.encode()

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "input_audio_buffer.commit")
    }

    func testCreateResponseWithoutConfig() throws {
        let event = ClientEvent.createResponse(nil)
        let data = try event.encode()

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "response.create")
        XCTAssertNil(json?["response"])
    }

    func testCreateResponseWithConfig() throws {
        let config = ClientEvent.ResponseConfig(
            instructions: "Be concise",
            voice: "shimmer",
            temperature: 0.8
        )

        let event = ClientEvent.createResponse(config)
        let data = try event.encode()

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["response"] as? [String: Any]

        XCTAssertEqual(response?["instructions"] as? String, "Be concise")
        XCTAssertEqual(response?["voice"] as? String, "shimmer")
        XCTAssertEqual(response?["temperature"] as? Double, 0.8)
    }

    func testTruncateResponseEncoding() throws {
        let event = ClientEvent.truncateResponse("resp_123", 5000)
        let data = try event.encode()

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "response.truncate")
        XCTAssertEqual(json?["response_id"] as? String, "resp_123")
        XCTAssertEqual(json?["audio_end_ms"] as? Int, 5000)
    }

    func testCancelResponseEncoding() throws {
        let event = ClientEvent.cancelResponse("resp_456")
        let data = try event.encode()

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "response.cancel")
        XCTAssertEqual(json?["response_id"] as? String, "resp_456")
    }

    func testServerVadHelper() {
        let turnDetection = ClientEvent.SessionUpdate.TurnDetection.serverVad(
            threshold: 0.7,
            prefixPaddingMs: 250,
            silenceDurationMs: 600,
            createResponse: false
        )

        XCTAssertEqual(turnDetection.type, "server_vad")
        XCTAssertEqual(turnDetection.threshold, 0.7)
        XCTAssertEqual(turnDetection.prefixPaddingMs, 250)
        XCTAssertEqual(turnDetection.silenceDurationMs, 600)
        XCTAssertEqual(turnDetection.createResponse, false)
    }

    func testServerVadDefaultValues() {
        let turnDetection = ClientEvent.SessionUpdate.TurnDetection.serverVad()

        XCTAssertEqual(turnDetection.type, "server_vad")
        XCTAssertEqual(turnDetection.threshold, 0.5)
        XCTAssertEqual(turnDetection.prefixPaddingMs, 300)
        XCTAssertEqual(turnDetection.silenceDurationMs, 500)
        XCTAssertEqual(turnDetection.createResponse, true)
    }
}
