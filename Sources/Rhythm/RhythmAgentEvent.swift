import Foundation

/// Chain identity, never inferred from an asset name or symbol.
public enum RhythmNetwork: UInt64, Sendable, Codable, CaseIterable {
    case ethereumMainnet = 1
    case robinhoodChain = 4663
}

/// Experimental request envelope, not a signable transaction or approval.
/// A host must independently obtain and validate transaction details before signing.
public struct RhythmTransactionRequest: Sendable, Equatable, Codable {
    public let id: UUID
    public let network: RhythmNetwork
    public let summary: String

    public init(id: UUID = UUID(), network: RhythmNetwork, summary: String) {
        self.id = id
        self.network = network
        self.summary = summary
    }
}

/// Reports the host's decision. A submitted hash is not proof of confirmation.
public struct RhythmTransactionResult: Sendable, Equatable, Codable {
    public enum Status: Sendable, Equatable, Codable {
        case declined
        case submitted(transactionHash: String)
        case failed(reason: String)
    }

    public let requestID: UUID
    public let status: Status

    public init(requestID: UUID, status: Status) {
        self.requestID = requestID
        self.status = status
    }
}

public enum RhythmAgentEvent: Sendable, Equatable {
    case connected(RhythmNetwork)
    case message(String)
    case transactionRequested(RhythmTransactionRequest)
    case transactionResult(RhythmTransactionResult)
    case disconnected
}

public enum RhythmError: Error, Sendable, Equatable {
    case publicAPIUnavailable
    case notConnected
    case alreadyConnected
    case closed
    case emptyMessage
    case unknownRequest
    case duplicateRequest
    case networkMismatch
}
