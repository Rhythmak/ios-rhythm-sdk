import Foundation

/// In-memory preview only: no AI, HTTP, WebSocket, RPC, wallet access or signing.
/// Events are buffered for one consumer. Disconnect finishes this single-use session.
public actor RhythmPreviewTransport: RhythmAgentTransport {
    public nonisolated let events: AsyncStream<RhythmAgentEvent>
    private let continuation: AsyncStream<RhythmAgentEvent>.Continuation
    private var network: RhythmNetwork?
    private var closed = false
    private var pending: Set<UUID> = []
    private var seen: Set<UUID> = []

    public init() {
        let pair = AsyncStream<RhythmAgentEvent>.makeStream()
        events = pair.stream
        continuation = pair.continuation
    }

    deinit { continuation.finish() }

    public func connect(network: RhythmNetwork) async throws {
        guard !closed else { throw RhythmError.closed }
        guard self.network == nil else { throw RhythmError.alreadyConnected }
        self.network = network
        continuation.yield(.connected(network))
    }

    public func send(text: String) async throws {
        guard network != nil else { throw RhythmError.notConnected }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RhythmError.emptyMessage
        }
        continuation.yield(.message("Local preview received: \(text)"))
    }

    /// Inserts a fictional request to exercise a host's review UI; performs no action.
    public func previewTransactionRequest(_ request: RhythmTransactionRequest) async throws {
        guard let network else { throw RhythmError.notConnected }
        guard request.network == network else { throw RhythmError.networkMismatch }
        guard seen.insert(request.id).inserted else { throw RhythmError.duplicateRequest }
        pending.insert(request.id)
        continuation.yield(.transactionRequested(request))
    }

    public func submit(result: RhythmTransactionResult) async throws {
        guard network != nil else { throw RhythmError.notConnected }
        guard pending.remove(result.requestID) != nil else { throw RhythmError.unknownRequest }
        continuation.yield(.transactionResult(result))
    }

    public func disconnect() async {
        guard !closed else { return }
        closed = true
        network = nil
        pending.removeAll()
        seen.removeAll()
        continuation.yield(.disconnected)
        continuation.finish()
    }
}
