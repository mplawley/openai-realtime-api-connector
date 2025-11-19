# OpenAI Realtime API Swift SDK

A SwiftUI-friendly package for connecting to OpenAI's Realtime API via WebRTC.

## Features

- `@Observable` support for SwiftUI integration
- Uses WebRTC binaries via stasel/WebRTC

## Installation

### Swift Package Manager

Add this package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/openai-realtime-api-connector", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version/branch (e.g. `main`)

## Quick Start

### Basic Usage

```swift
import OpenAIRealtimeAPI
import SwiftUI

@MainActor
class ConversationViewModel {
    let conversation: RealtimeConversation

    init() throws {
        conversation = try RealtimeConversation()
    }

    func connect(ephemeralKey: String) async throws {
        // Connect to the API
        try await conversation.connect(ephemeralKey: ephemeralKey)

        // Configure the session
        try conversation.updateSession { session in
            session.instructions = "You are a helpful medical assistant."
            session.voice = "alloy"
            session.inputAudioTranscription = .init(model: "whisper-1", language: "en")
            session.turnDetection = .serverVad(
                threshold: 0.5,
                prefixPaddingMs: 300,
                silenceDurationMs: 500
            )
        }
    }
}

struct ConversationView: View {
    @State private var viewModel: ConversationViewModel

    init() {
        _viewModel = State(wrappedValue: try! ConversationViewModel())
    }

    var body: some View {
        VStack {
            // Connection status
            Text("Status: \(viewModel.conversation.connectionState)")

            // Messages list
            ScrollView {
                ForEach(viewModel.conversation.messages, id: \.id) { message in
                    MessageBubble(message: message)
                }
            }

            // Speaking indicators
            if viewModel.conversation.isUserSpeaking {
                Text("You are speaking...")
            }

            if viewModel.conversation.isAssistantSpeaking {
                Text("Assistant is speaking...")
            }
        }
        .task {
            try? await viewModel.connect(ephemeralKey: "your-ephemeral-key")
        }
    }
}
```

### Sending Audio

```swift
// Append audio data (PCM16, 24kHz, mono)
try conversation.appendAudio(audioData)

// Commit audio to trigger response (if turn detection is disabled)
try conversation.commitAudio()
```

### Manual Response Triggering

```swift
// Request a response from the assistant
try conversation.createResponse()

// With custom configuration
let config = ClientEvent.ResponseConfig(
    instructions: "Be very concise",
    voice: "shimmer",
    temperature: 0.7
)
try conversation.createResponse(config: config)
```

### Handling Errors

```swift
// Errors are automatically collected
for error in conversation.errors {
    print("Error: \(error.message)")
}

// Enable debug mode for detailed logging
conversation.debugMode = true
```

## Architecture

### Core Components

1. **RealtimeConversation**: Main SwiftUI-friendly conversation manager
   - Observable state for automatic UI updates
   - MainActor-isolated for thread safety
   - Clean, documented public API

2. **WebRTCManager**: WebRTC connection handling
   - Manages peer connection and data channels
   - Handles SDP exchange with OpenAI
   - Audio track management

3. **Models**: Type-safe event and data structures
   - `ServerEvent`: Events from OpenAI (with flexible decoding)
   - `ClientEvent`: Events to OpenAI (with type-safe encoding)
   - `Item`: Conversation items (messages, function calls, etc.)

### Event Flow

```
OpenAI Realtime API
        ↓
   WebRTC Data Channel
        ↓
    WebRTCManager
        ↓
   ServerEvent.decode() ← Flexible JSON parsing
        ↓
  RealtimeConversation  ← MainActor state updates
        ↓
    SwiftUI View       ← Automatic re-rendering
```

## Advanced Usage

### Custom Session Configuration

```swift
try conversation.updateSession { session in
    // Set system instructions
    session.instructions = """
        You are roleplaying as a virtual patient named \(patient.name).
        Speak in \(language).
        Your comprehension level is \(comprehension)%.
        """

    // Configure voice
    session.voice = "coral"

    // Enable transcription
    session.inputAudioTranscription = .init(
        model: "whisper-1",
        language: "es"  // Spanish
    )

    // Semantic VAD (more natural turn detection)
    session.turnDetection = .init(
        type: "semantic_vad",
        threshold: nil,
        prefixPaddingMs: nil,
        silenceDurationMs: nil,
        createResponse: true
    )
}
```

### Monitoring Connection State

```swift
// Watch for state changes
switch conversation.connectionState {
case .disconnected:
    print("Not connected")
case .connecting:
    print("Connecting...")
case .connected:
    print("Connected and ready")
case .failed:
    print("Connection failed")
}

// Wait for connection
await conversation.waitForConnection()
```

### Accessing Specific Content Types

```swift
// Get only messages (excludes function calls)
let messages = conversation.messages

// Get all items (including function calls)
let allItems = conversation.items

// Filter by message role
let userMessages = conversation.messages.filter { $0.role == .user }
let assistantMessages = conversation.messages.filter { $0.role == .assistant }

// Extract display text
for message in conversation.messages {
    for content in message.content {
        if let text = content.displayText {
            print(text)
        }
    }
}
```

## Testing

The package includes tests that you can run within XCode or via this command:

```bash
swift test
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 15.0+

## Dependencies

- [WebRTC](https://github.com/stasel/WebRTC): Community-supported WebRTC binaries for iOS/macOS

## Contributing

Contributions are welcome! Please:

1. Write tests for new features
2. Follow the existing code style (short methods, clear names)
3. Update documentation
4. Ensure all tests pass
