import XCTest
@testable import OpenAIRealtimeAPI

final class ServerEventTests: XCTestCase {
    func testErrorEventDecoding() {
        let json = """
        {
            "type": "error",
            "error": {
                "type": "invalid_request_error",
                "code": "invalid_value",
                "message": "Invalid parameter value",
                "param": "temperature"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .error(let error) = event else {
            XCTFail("Expected error event")
            return
        }

        XCTAssertEqual(error.type, "invalid_request_error")
        XCTAssertEqual(error.code, "invalid_value")
        XCTAssertEqual(error.message, "Invalid parameter value")
        XCTAssertEqual(error.param, "temperature")
    }

    func testSessionCreatedDecoding() {
        let json = """
        {
            "type": "session.created",
            "session": {
                "instructions": "You are a helpful assistant",
                "voice": "alloy"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .sessionCreated(let session) = event else {
            XCTFail("Expected sessionCreated event")
            return
        }

        XCTAssertEqual(session.instructions, "You are a helpful assistant")
        XCTAssertEqual(session.voice, .alloy)
    }

    func testSessionUpdatedWithTurnDetection() {
        let json = """
        {
            "type": "session.updated",
            "session": {
                "instructions": "New instructions",
                "turn_detection": {
                    "type": "server_vad",
                    "threshold": 0.6,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500
                }
            }
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .sessionUpdated(let session) = event else {
            XCTFail("Expected sessionUpdated event")
            return
        }

        XCTAssertEqual(session.instructions, "New instructions")
        XCTAssertEqual(session.turnDetection?.type, "server_vad")
        XCTAssertEqual(session.turnDetection?.threshold, 0.6)
        XCTAssertEqual(session.turnDetection?.prefixPaddingMs, 300)
        XCTAssertEqual(session.turnDetection?.silenceDurationMs, 500)
    }

    func testConversationCreatedDecoding() {
        let json = """
        {
            "type": "conversation.created",
            "conversation": {
                "id": "conv_123"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .conversationCreated(let id) = event else {
            XCTFail("Expected conversationCreated event")
            return
        }

        XCTAssertEqual(id, "conv_123")
    }

    func testConversationItemDeletedDecoding() {
        let json = """
        {
            "type": "conversation.item.deleted",
            "item_id": "item_123"
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .conversationItemDeleted(let itemId) = event else {
            XCTFail("Expected conversationItemDeleted event")
            return
        }

        XCTAssertEqual(itemId, "item_123")
    }

    func testInputAudioTranscriptionCompleted() {
        let json = """
        {
            "type": "conversation.item.input_audio_transcription.completed",
            "item_id": "item_123",
            "transcript": "Hello, how are you?",
            "usage": {
                "type": "duration",
                "seconds": 3
            }
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .conversationItemInputAudioTranscriptionCompleted(let itemId, let transcript) = event else {
            XCTFail("Expected transcription completed event")
            return
        }

        XCTAssertEqual(itemId, "item_123")
        XCTAssertEqual(transcript, "Hello, how are you?")
    }

    func testInputAudioTranscriptionFailed() {
        let json = """
        {
            "type": "conversation.item.input_audio_transcription.failed",
            "item_id": "item_123",
            "error": {
                "type": "transcription_error",
                "message": "Failed to transcribe audio"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .conversationItemInputAudioTranscriptionFailed(let itemId, let error) = event else {
            XCTFail("Expected transcription failed event")
            return
        }

        XCTAssertEqual(itemId, "item_123")
        XCTAssertEqual(error.message, "Failed to transcribe audio")
    }

    func testResponseCreatedDecoding() {
        let json = """
        {
            "type": "response.created",
            "response": {
                "id": "resp_123",
                "status": "in_progress"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .responseCreated(let response) = event else {
            XCTFail("Expected responseCreated event")
            return
        }

        XCTAssertEqual(response.id, "resp_123")
        XCTAssertEqual(response.status, .inProgress)
    }

    func testResponseTextDelta() {
        let json = """
        {
            "type": "response.text.delta",
            "item_id": "item_123",
            "content_index": 0,
            "delta": "Hello"
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .responseTextDelta(let itemId, let contentIndex, let delta) = event else {
            XCTFail("Expected responseTextDelta event")
            return
        }

        XCTAssertEqual(itemId, "item_123")
        XCTAssertEqual(contentIndex, 0)
        XCTAssertEqual(delta, "Hello")
    }

    func testResponseAudioTranscriptDelta() {
        let json = """
        {
            "type": "response.audio_transcript.delta",
            "item_id": "item_123",
            "content_index": 0,
            "delta": " world"
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .responseAudioTranscriptDelta(let itemId, let contentIndex, let delta) = event else {
            XCTFail("Expected responseAudioTranscriptDelta event")
            return
        }

        XCTAssertEqual(itemId, "item_123")
        XCTAssertEqual(contentIndex, 0)
        XCTAssertEqual(delta, " world")
    }

    func testInputAudioBufferEvents() {
        let startJson = """
        {"type": "input_audio_buffer.speech_started"}
        """

        let stopJson = """
        {"type": "input_audio_buffer.speech_stopped"}
        """

        let startEvent = ServerEvent.decode(from: startJson.data(using: .utf8)!)
        let stopEvent = ServerEvent.decode(from: stopJson.data(using: .utf8)!)

        XCTAssertNotNil(startEvent)
        XCTAssertNotNil(stopEvent)

        if case .inputAudioBufferSpeechStarted = startEvent! {} else {
            XCTFail("Expected inputAudioBufferSpeechStarted")
        }

        if case .inputAudioBufferSpeechStopped = stopEvent! {} else {
            XCTFail("Expected inputAudioBufferSpeechStopped")
        }
    }

    func testOutputAudioBufferEvents() {
        let startJson = """
        {"type": "output_audio_buffer.started"}
        """

        let stopJson = """
        {"type": "output_audio_buffer.stopped"}
        """

        let clearJson = """
        {"type": "output_audio_buffer.cleared"}
        """

        let startEvent = ServerEvent.decode(from: startJson.data(using: .utf8)!)
        let stopEvent = ServerEvent.decode(from: stopJson.data(using: .utf8)!)
        let clearEvent = ServerEvent.decode(from: clearJson.data(using: .utf8)!)

        if case .outputAudioBufferStarted = startEvent! {} else {
            XCTFail("Expected outputAudioBufferStarted")
        }

        if case .outputAudioBufferStopped = stopEvent! {} else {
            XCTFail("Expected outputAudioBufferStopped")
        }

        if case .outputAudioBufferCleared = clearEvent! {} else {
            XCTFail("Expected outputAudioBufferCleared")
        }
    }

    func testUnknownEventHandling() {
        let json = """
        {
            "type": "some.new.event",
            "data": "test"
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        guard case .unknown(let type) = event else {
            XCTFail("Expected unknown event")
            return
        }

        XCTAssertEqual(type, "some.new.event")
    }

    func testMalformedEventReturnsNil() {
        let json = """
        {
            "invalid": "json",
            "no": "type"
        }
        """

        let data = json.data(using: .utf8)!
        let event = ServerEvent.decode(from: data)

        XCTAssertNil(event)
    }

    func testInvalidJSONReturnsNil() {
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        let event = ServerEvent.decode(from: invalidData)

        XCTAssertNil(event)
    }
}
