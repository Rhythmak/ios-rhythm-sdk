import XCTest
@testable import Rhythm

final class RhythmTests: XCTestCase {
    func testDefaultAdapterIsExplicitlyUnavailable() async {
        let agent = RhythmAgentBuilder.shared.build(network: .ethereumMainnet)
        do { try await agent.connect(); XCTFail("Must not connect to any service") }
        catch { XCTAssertEqual(error as? RhythmError, .publicAPIUnavailable) }
        do { try await agent.send(text: "Hello"); XCTFail("Must not send to any service") }
        catch { XCTAssertEqual(error as? RhythmError, .publicAPIUnavailable) }
        var iterator = agent.events.makeAsyncIterator()
        let event = await iterator.next()
        XCTAssertNil(event)
    }

    func testPreviewLifecycleAndMessageDelivery() async throws {
        let preview = RhythmPreviewTransport()
        let agent = RhythmAgentBuilder.shared.build(network: .robinhoodChain, transport: preview)
        var iterator = agent.events.makeAsyncIterator()
        try await agent.connect()
        let connected = await iterator.next()
        XCTAssertEqual(connected, .connected(.robinhoodChain))
        try await agent.send(text: "Hello Rhythm")
        let message = await iterator.next()
        XCTAssertEqual(message, .message("Local preview received: Hello Rhythm"))
        await agent.disconnect()
        let disconnected = await iterator.next()
        XCTAssertEqual(disconnected, .disconnected)
        let end = await iterator.next()
        XCTAssertNil(end)
        do { try await agent.connect(); XCTFail("A finished stream cannot reconnect") }
        catch { XCTAssertEqual(error as? RhythmError, .closed) }
    }

    func testRequestNeedsExplicitHostResultAndRejectsReplay() async throws {
        let preview = RhythmPreviewTransport()
        let agent = RhythmAgentBuilder.shared.build(network: .robinhoodChain, transport: preview)
        var iterator = agent.events.makeAsyncIterator()
        try await agent.connect()
        _ = await iterator.next()
        let request = RhythmTransactionRequest(network: .robinhoodChain, summary: "Preview only")
        try await preview.previewTransactionRequest(request)
        let event = await iterator.next()
        XCTAssertEqual(event, .transactionRequested(request))
        let result = RhythmTransactionResult(requestID: request.id, status: .declined)
        try await agent.submit(result: result)
        let reply = await iterator.next()
        XCTAssertEqual(reply, .transactionResult(result))
        do { try await agent.submit(result: result); XCTFail("Duplicate result") }
        catch { XCTAssertEqual(error as? RhythmError, .unknownRequest) }
        do { try await preview.previewTransactionRequest(request); XCTFail("Reused request ID") }
        catch { XCTAssertEqual(error as? RhythmError, .duplicateRequest) }
        await agent.disconnect()
    }

    func testDisconnectedEmptyAndWrongNetworkInputs() async throws {
        let preview = RhythmPreviewTransport()
        let agent = RhythmAgentBuilder.shared.build(network: .ethereumMainnet, transport: preview)
        do { try await agent.send(text: "Hi"); XCTFail("Disconnected") }
        catch { XCTAssertEqual(error as? RhythmError, .notConnected) }
        try await agent.connect()
        do { try await agent.send(text: " \n "); XCTFail("Empty") }
        catch { XCTAssertEqual(error as? RhythmError, .emptyMessage) }
        do {
            try await preview.previewTransactionRequest(.init(network: .robinhoodChain, summary: "Wrong network"))
            XCTFail("Mismatched chain")
        } catch { XCTAssertEqual(error as? RhythmError, .networkMismatch) }
        await agent.disconnect()
    }

    func testIndependentSessionsAndResultEncoding() async throws {
        let first = RhythmPreviewTransport(), second = RhythmPreviewTransport()
        try await first.connect(network: .ethereumMainnet)
        try await second.connect(network: .ethereumMainnet)
        let request = RhythmTransactionRequest(network: .ethereumMainnet, summary: "Preview only")
        try await first.previewTransactionRequest(request)
        let result = RhythmTransactionResult(requestID: request.id, status: .submitted(transactionHash: "preview-hash"))
        do { try await second.submit(result: result); XCTFail("Another session's request") }
        catch { XCTAssertEqual(error as? RhythmError, .unknownRequest) }
        XCTAssertEqual(try JSONDecoder().decode(RhythmTransactionResult.self, from: JSONEncoder().encode(result)), result)
        await first.disconnect()
        await second.disconnect()
    }
}
