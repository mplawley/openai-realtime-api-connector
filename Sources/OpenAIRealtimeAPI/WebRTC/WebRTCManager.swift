import Foundation
import WebRTC

/// Manages WebRTC peer connection and data channels for OpenAI's Realtime API
@MainActor
public final class WebRTCManager: NSObject, @unchecked Sendable {
    private let peerConnection: RTCPeerConnection
    private let dataChannel: RTCDataChannel
    private let audioTrack: RTCAudioTrack?
    private let peerConnectionFactory: RTCPeerConnectionFactory

    private var eventHandler: (@Sendable (Data) -> Void)?
    private var stateChangeHandler: (@Sendable (ConnectionState) -> Void)?

    public enum ConnectionState: Sendable {
        case disconnected
        case connecting
        case connected
        case failed
    }

    public override init() {
        // Initialize WebRTC factory
        RTCInitializeSSL()
        peerConnectionFactory = RTCPeerConnectionFactory()

        // Configure peer connection
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        guard let pc = peerConnectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: nil
        ) else {
            fatalError("Failed to create peer connection")
        }

        self.peerConnection = pc

        // Create data channel
        let dataChannelConfig = RTCDataChannelConfiguration()
        dataChannelConfig.isOrdered = true

        guard let dc = peerConnection.dataChannel(
            forLabel: "oai-events",
            configuration: dataChannelConfig
        ) else {
            fatalError("Failed to create data channel")
        }

        self.dataChannel = dc

        // Set up audio track
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = peerConnectionFactory.audioSource(with: audioConstraints)
        let audioTrack = peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio")
        peerConnection.add(audioTrack, streamIds: ["stream"])
        self.audioTrack = audioTrack

        super.init()

        // Set delegates
        peerConnection.delegate = self
        dataChannel.delegate = self
    }

    deinit {
        RTCCleanupSSL()
    }

    /// Connect to the OpenAI Realtime API
    public func connect(ephemeralKey: String, model: String = "gpt-4o-realtime-preview-2024-10-01") async throws {
        stateChangeHandler?(.connecting)

        // Create offer
        let offer = try await createOffer()

        // Exchange SDP with OpenAI
        let answer = try await exchangeSDP(offer: offer, ephemeralKey: ephemeralKey, model: model)

        // Set remote description
        try await setRemoteDescription(answer)

        stateChangeHandler?(.connected)
    }

    /// Disconnect from the API
    public func disconnect() {
        dataChannel.close()
        peerConnection.close()
        stateChangeHandler?(.disconnected)
    }

    /// Send an event to the server
    public func send(event: ClientEvent) throws {
        let data = try event.encode()
        let buffer = RTCDataBuffer(data: data, isBinary: false)

        guard dataChannel.readyState == .open else {
            throw WebRTCError.dataChannelNotOpen
        }

        dataChannel.sendData(buffer)
    }

    /// Set handler for incoming server events
    public func onEvent(_ handler: @escaping @Sendable (Data) -> Void) {
        eventHandler = handler
    }

    /// Set handler for connection state changes
    public func onStateChange(_ handler: @escaping @Sendable (ConnectionState) -> Void) {
        stateChangeHandler = handler
    }

    private func createOffer() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            peerConnection.offer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)) { sdp, error in
                if let error = error {
                    continuation.resume(throwing: WebRTCError.failedToCreateOffer(error))
                    return
                }

                guard let sdp = sdp else {
                    continuation.resume(throwing: WebRTCError.invalidSDP)
                    return
                }

                self.peerConnection.setLocalDescription(sdp) { error in
                    if let error = error {
                        continuation.resume(throwing: WebRTCError.failedToSetLocalDescription(error))
                        return
                    }

                    continuation.resume(returning: sdp.sdp)
                }
            }
        }
    }

    private func exchangeSDP(offer: String, ephemeralKey: String, model: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/realtime")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(ephemeralKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = offer.data(using: .utf8)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.queryItems = [URLQueryItem(name: "model", value: model)]

        if let urlWithQuery = components.url {
            request.url = urlWithQuery
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WebRTCError.invalidResponse
        }

        guard let answer = String(data: data, encoding: .utf8) else {
            throw WebRTCError.invalidSDP
        }

        return answer
    }

    private func setRemoteDescription(_ sdp: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
            peerConnection.setRemoteDescription(sessionDescription) { error in
                if let error = error {
                    continuation.resume(throwing: WebRTCError.failedToSetRemoteDescription(error))
                    return
                }

                continuation.resume()
            }
        }
    }
}

extension WebRTCManager: RTCPeerConnectionDelegate {
    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    nonisolated public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor in
            switch newState {
            case .connected:
                stateChangeHandler?(.connected)
            case .disconnected, .closed:
                stateChangeHandler?(.disconnected)
            case .failed:
                stateChangeHandler?(.failed)
            default:
                break
            }
        }
    }

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

extension WebRTCManager: RTCDataChannelDelegate {
    nonisolated public func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {}

    nonisolated public func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        let data = buffer.data
        Task { @MainActor [weak self] in
            self?.eventHandler?(data)
        }
    }
}

public enum WebRTCError: Error, LocalizedError {
    case failedToCreatePeerConnection
    case failedToCreateDataChannel
    case failedToCreateOffer(Error)
    case failedToSetLocalDescription(Error)
    case failedToSetRemoteDescription(Error)
    case invalidSDP
    case invalidResponse
    case dataChannelNotOpen

    public var errorDescription: String? {
        switch self {
        case .failedToCreatePeerConnection:
            return "Failed to create WebRTC peer connection"
        case .failedToCreateDataChannel:
            return "Failed to create data channel"
        case .failedToCreateOffer(let error):
            return "Failed to create offer: \(error.localizedDescription)"
        case .failedToSetLocalDescription(let error):
            return "Failed to set local description: \(error.localizedDescription)"
        case .failedToSetRemoteDescription(let error):
            return "Failed to set remote description: \(error.localizedDescription)"
        case .invalidSDP:
            return "Invalid SDP"
        case .invalidResponse:
            return "Invalid response from server"
        case .dataChannelNotOpen:
            return "Data channel is not open"
        }
    }
}
