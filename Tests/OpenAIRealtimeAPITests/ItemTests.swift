import XCTest
@testable import OpenAIRealtimeAPI

final class ItemTests: XCTestCase {
    /**
     These tests exercise the actual Item.Message objects.
     */

    func testMessageCreation() {
        let message = Item.Message(
            id: "msg_123",
            role: .user,
            content: [.text("Hello, world!")]
        )

        XCTAssertEqual(message.id, "msg_123")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content.count, 1)

        if case .text(let text) = message.content[0] {
            XCTAssertEqual(text, "Hello, world!")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testMessageDisplayText() {
        let textContent = Item.Message.Content.text("Hello")
        XCTAssertEqual(textContent.displayText, "Hello")

        let inputTextContent = Item.Message.Content.inputText("Input")
        XCTAssertEqual(inputTextContent.displayText, "Input")

        let audio = Item.Message.Audio(transcript: "Transcribed")
        let audioContent = Item.Message.Content.audio(audio)
        XCTAssertEqual(audioContent.displayText, "Transcribed")

        let audioWithoutTranscript = Item.Message.Audio()
        let audioContentNoTranscript = Item.Message.Content.audio(audioWithoutTranscript)
        XCTAssertNil(audioContentNoTranscript.displayText)
    }

    func testFunctionCallCreation() {
        let functionCall = Item.FunctionCall(
            id: "fc_123",
            callId: "call_456",
            name: "get_weather",
            arguments: "{\"location\":\"San Francisco\"}"
        )

        XCTAssertEqual(functionCall.id, "fc_123")
        XCTAssertEqual(functionCall.callId, "call_456")
        XCTAssertEqual(functionCall.name, "get_weather")
        XCTAssertEqual(functionCall.arguments, "{\"location\":\"San Francisco\"}")
    }

    func testFunctionCallOutputCreation() {
        let output = Item.FunctionCallOutput(
            id: "fco_123",
            callId: "call_456",
            output: "{\"temperature\":72}"
        )

        XCTAssertEqual(output.id, "fco_123")
        XCTAssertEqual(output.callId, "call_456")
        XCTAssertEqual(output.output, "{\"temperature\":72}")
    }

    func testItemEquality() {
        let message1 = Item.message(Item.Message(id: "123", role: .user, content: [.text("Hello")]))
        let message2 = Item.message(Item.Message(id: "123", role: .assistant, content: [.text("Hi")]))
        let message3 = Item.message(Item.Message(id: "456", role: .user, content: [.text("Hello")]))

        XCTAssertEqual(message1, message2) // Same ID
        XCTAssertNotEqual(message1, message3) // Different ID
    }

    func testItemID() {
        let messageItem = Item.message(Item.Message(id: "msg_123", role: .user, content: []))
        XCTAssertEqual(messageItem.id, "msg_123")

        let callItem = Item.functionCall(Item.FunctionCall(id: "fc_123", callId: "call", name: "test", arguments: "{}"))
        XCTAssertEqual(callItem.id, "fc_123")

        let outputItem = Item.functionCallOutput(Item.FunctionCallOutput(id: "fco_123", callId: "call", output: "{}"))
        XCTAssertEqual(outputItem.id, "fco_123")
    }

    func testMessageEncoding() throws {
        let message = Item.Message(
            id: "msg_123",
            role: .assistant,
            content: [.text("Hello"), .inputText("World")]
        )

        let item = Item.message(message)

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Item.self, from: data)

        XCTAssertEqual(item, decoded)
    }

    func testFunctionCallEncoding() throws {
        let call = Item.FunctionCall(
            id: "fc_123",
            callId: "call_456",
            name: "get_weather",
            arguments: "{}"
        )

        let item = Item.functionCall(call)

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Item.self, from: data)

        XCTAssertEqual(item, decoded)
    }
}
