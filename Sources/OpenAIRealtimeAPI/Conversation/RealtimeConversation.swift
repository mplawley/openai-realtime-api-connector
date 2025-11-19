import Foundation
import Observation

/**
 A conversation manager for OpenAI's Realtime API
 This class is designed to work seamlessly with SwiftUI's observation system.
 State updates happen on the MainActor thread, ensuring UI updates are triggered.
 */
@MainActor
@Observable
public final class RealtimeConversation {
    /// The current connection state
    public private(set) var connectionState: ConnectionState = .disconnected

    /// All conversation items (messages, function calls, etc.)
    public private(set) var items: [Item] = []

    /// Current session configuration
    public private(set) var session: ServerEvent.Session?

    /// Whether the user is currently speaking (requires server VAD)
    public private(set) var isUserSpeaking = false

    /// Whether the assistant is currently speaking
    public private(set) var isAssistantSpeaking = false

    /// Errors that occur during the conversation
    public private(set) var errors: [ServerEvent.Error] = []

    /// Debugging output enabled
    public var debugMode = false

    /// Only the message items from the conversation
    public var messages: [Item.Message] {
        items.compactMap {
            if case .message(let message) = $0 {
                return message
            }
            return nil
        }
    }

    private let webRTCManager: WebRTCManager

    public init() {
        self.webRTCManager = WebRTCManager()
        setupEventHandlers()
    }

    /// Connect to the OpenAI Realtime API
    public func connect(ephemeralKey: String, model: String = "gpt-realtime") async throws {
        try await webRTCManager.connect(ephemeralKey: ephemeralKey, model: model)
    }

    /// Wait for connection to be established
    public func waitForConnection() async {
        while connectionState != .connected {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Disconnect from the API
    public func disconnect() {
        webRTCManager.disconnect()
    }

    /// Update the session configuration
    public func updateSession(_ configuration: @escaping (inout ClientEvent.SessionUpdate) -> Void) throws {
        var update = ClientEvent.SessionUpdate()
        configuration(&update)
        try webRTCManager.send(event: .updateSession(update))
    }

    /// Append audio data to the input buffer
    public func appendAudio(_ data: Data) throws {
        try webRTCManager.send(event: .appendInputAudioBuffer(data))
    }

    /// Commit the current audio buffer (triggers response if turn detection is disabled)
    public func commitAudio() throws {
        try webRTCManager.send(event: .commitInputAudioBuffer)
    }

    /// Request a response from the assistant
    public func createResponse(config: ClientEvent.ResponseConfig? = nil) throws {
        try webRTCManager.send(event: .createResponse(config))
    }

    /// Cancel an in-progress response
    public func cancelResponse(_ responseId: String) throws {
        try webRTCManager.send(event: .cancelResponse(responseId))
    }

    private func setupEventHandlers() {
        // Handle connection state changes
        webRTCManager.onStateChange { [weak self] state in
            Task { @MainActor in
                self?.handleStateChange(state)
            }
        }

        // Handle incoming server events
        webRTCManager.onEvent { [weak self] data in
            Task { @MainActor in
                await self?.handleEventData(data)
            }
        }
    }

    private func handleStateChange(_ state: WebRTCManager.ConnectionState) {
        switch state {
        case .disconnected:
            connectionState = .disconnected
        case .connecting:
            connectionState = .connecting
        case .connected:
            connectionState = .connected
        case .failed:
            connectionState = .failed
        }
    }

    private func handleEventData(_ data: Data) async {
        guard let event = ServerEvent.decode(from: data) else {
            if debugMode {
                if let json = try? JSONSerialization.jsonObject(with: data),
                   let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                   let string = String(data: prettyData, encoding: .utf8) {
                    print("[RealtimeConversation] Failed to decode event:\n\(string)")
                }
            }
            return
        }

        if debugMode {
            print("[RealtimeConversation] Received event: \(event)")
        }

        await handleServerEvent(event)
    }

    private func handleServerEvent(_ event: ServerEvent) async {
        switch event {
        case .error(let error):
            errors.append(error)
            if debugMode {
                print("[RealtimeConversation] Error: \(error.message)")
            }

        case .sessionCreated(let newSession), .sessionUpdated(let newSession):
            session = newSession

        case .conversationCreated:
            break // Conversation ID tracked internally

        case .conversationItemCreated(let item):
            items.append(item)

        case .conversationItemDeleted(let itemId):
            items.removeAll { $0.id == itemId }

        case .conversationItemTruncated(let itemId, _, _):
            if debugMode {
                print("[RealtimeConversation] Item truncated: \(itemId)")
            }
            // Truncation happens when user interrupts the assistant
            // The item stays in the conversation but audio playback stops

        case .conversationItemInputAudioTranscriptionCompleted(let itemId, let transcript):
            updateMessageContent(itemId: itemId) { content in
                guard content.count > 0 else { return }
                if case .inputAudio(var audio) = content[0] {
                    audio.transcript = transcript
                    content[0] = .inputAudio(audio)
                }
            }

        case .conversationItemInputAudioTranscriptionFailed(_, let error):
            errors.append(error)

        case .responseCreated, .responseDone:
            break // Response lifecycle tracked by items

        case .responseOutputItemAdded:
            // Output item added to response
            break

        case .responseAudioTranscriptDelta(let itemId, let contentIndex, let delta):
            updateMessageContent(itemId: itemId) { content in
                guard contentIndex < content.count else { return }
                if case .audio(var audio) = content[contentIndex] {
                    audio.transcript = (audio.transcript ?? "") + delta
                    content[contentIndex] = .audio(audio)
                }
            }

        case .responseAudioTranscriptDone(let itemId, let contentIndex, let transcript):
            updateMessageContent(itemId: itemId) { content in
                guard contentIndex < content.count else { return }
                if case .audio(var audio) = content[contentIndex] {
                    audio.transcript = transcript
                    content[contentIndex] = .audio(audio)
                }
            }

        case .responseTextDelta(let itemId, let contentIndex, let delta):
            updateMessageContent(itemId: itemId) { content in
                guard contentIndex < content.count else { return }
                if case .text(let text) = content[contentIndex] {
                    content[contentIndex] = .text(text + delta)
                }
            }

        case .responseTextDone(let itemId, let contentIndex, let text):
            updateMessageContent(itemId: itemId) { content in
                guard contentIndex < content.count else { return }
                content[contentIndex] = .text(text)
            }

        case .responseContentPartAdded(let itemId, let contentIndex):
            // Add a new content part (initially empty audio with no transcript)
            updateMessageContent(itemId: itemId) { content in
                // Ensure we have enough slots
                while content.count <= contentIndex {
                    content.append(.audio(Item.Message.Audio()))
                }
            }

        case .responseContentPartDone:
            break

        case .responseAudioDone:
            // Audio streaming complete for this content part
            break

        case .responseOutputItemDone:
            // Complete output item generated
            break

        case .inputAudioBufferCommitted:
            if debugMode {
                print("[RealtimeConversation] Input audio buffer committed")
            }

        case .inputAudioBufferSpeechStarted:
            isUserSpeaking = true
            if debugMode {
                print("[RealtimeConversation] User started speaking")
            }

        case .inputAudioBufferSpeechStopped:
            isUserSpeaking = false
            if debugMode {
                print("[RealtimeConversation] User stopped speaking")
            }

        case .outputAudioBufferStarted:
            isAssistantSpeaking = true
            if debugMode {
                print("[RealtimeConversation] Assistant started speaking")
            }

        case .outputAudioBufferStopped, .outputAudioBufferCleared:
            isAssistantSpeaking = false
            if debugMode {
                print("[RealtimeConversation] Assistant stopped speaking")
            }

        case .rateLimitsUpdated:
            break // Can be tracked if needed

        case .unknown(let type):
            if debugMode {
                print("[RealtimeConversation] Unknown event type: '\(type)'")
            }
        }
    }

    private func updateMessageContent(itemId: String, updater: (inout [Item.Message.Content]) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == itemId }),
              case .message(var message) = items[index] else {
            return
        }

        updater(&message.content)
        items[index] = .message(message)
    }
}

extension RealtimeConversation {
    public enum ConnectionState: Sendable {
        case disconnected
        case connecting
        case connected
        case failed
    }
}
