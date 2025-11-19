/// OpenAI Realtime API Swift SDK
///
/// A robust, SwiftUI-friendly SDK for connecting to OpenAI's Realtime API via WebRTC.
///
/// ## Overview
///
/// This SDK provides a clean, type-safe interface to OpenAI's Realtime API with:
/// - Proper SwiftUI `@Observable` integration
/// - Flexible event decoding that handles API changes gracefully
/// - WebRTC connection management using official Google WebRTC binaries
/// - MainActor-isolated state updates for reliable UI synchronization
///
/// ## Basic Usage
///
/// ```swift
/// import OpenAIRealtimeAPI
/// import SwiftUI
///
/// @MainActor
/// class ConversationViewModel {
///     let conversation: RealtimeConversation
///
///     init() {
///         conversation = try! RealtimeConversation()
///     }
///
///     func connect(ephemeralKey: String) async throws {
///         try await conversation.connect(ephemeralKey: ephemeralKey)
///         try conversation.updateSession { session in
///             session.instructions = "You are a helpful assistant."
///             session.voice = "alloy"
///             session.turnDetection = .serverVad()
///         }
///     }
/// }
///
/// struct ConversationView: View {
///     @State private var viewModel = ConversationViewModel()
///
///     var body: some View {
///         List(viewModel.conversation.messages, id: \.id) { message in
///             MessageRow(message: message)
///         }
///     }
/// }
/// ```
///
/// ## Key Features
///
/// - **Type-Safe Events**: All server and client events are strongly typed
/// - **Flexible Decoding**: Unknown events don't crash the event loop
/// - **Observable State**: All properties are observable for SwiftUI
/// - **MainActor Safety**: All public APIs are MainActor-isolated
///
/// ## License
///
/// This package is provided under the MIT license.

import Foundation

@_exported import struct Foundation.Data
@_exported import class Foundation.URLSession

// Export public types
public typealias Conversation = RealtimeConversation
