import Foundation

/// Experimental adapter boundary. No network transport or wire protocol is shipped.
/// Use one event consumer per transport and a new transport for each session.
public protocol RhythmAgentTransport: Sendable {
    var events: AsyncStream<RhythmAgentEvent> { get }
    func connect(network: RhythmNetwork) async throws
    func send(text: String) async throws
    func submit(result: RhythmTransactionResult) async throws
    func disconnect() async
}

public struct RhythmAgent: Sendable {
    public let network: RhythmNetwork
    private let transport: any RhythmAgentTransport

    internal init(network: RhythmNetwork, transport: any RhythmAgentTransport) {
        self.network = network
        self.transport = transport
    }

    public var events: AsyncStream<RhythmAgentEvent> { transport.events }

    public func connect() async throws {
        try await transport.connect(network: network)
    }

    public func send(text: String) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RhythmError.emptyMessage
        }
        try await transport.send(text: text)
    }

    public func submit(result: RhythmTransactionResult) async throws {
        try await transport.submit(result: result)
    }

    public func disconnect() async { await transport.disconnect() }
}

public struct RhythmAgentBuilder: Sendable {
    public static let shared = RhythmAgentBuilder()
    public init() {}

    /// Without an explicit adapter, connect/send/submit throw publicAPIUnavailable.
    public func build(
        network: RhythmNetwork,
        transport: (any RhythmAgentTransport)? = nil
    ) -> RhythmAgent {
        RhythmAgent(network: network, transport: transport ?? UnavailableTransport())
    }
}

private struct UnavailableTransport: RhythmAgentTransport {
    let events = AsyncStream<RhythmAgentEvent> { $0.finish() }
    func connect(network: RhythmNetwork) async throws { throw RhythmError.publicAPIUnavailable }
    func send(text: String) async throws { throw RhythmError.publicAPIUnavailable }
    func submit(result: RhythmTransactionResult) async throws { throw RhythmError.publicAPIUnavailable }
    func disconnect() async {}
}
