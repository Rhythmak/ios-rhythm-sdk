# RHYTHM

Official iOS SDK for interacting with the RHYTHM agent.

## About

RHYTHM brings a crypto wallet and a conversational agent into one place. Users can
ask about their on-chain assets and review proposed actions while keeping control
of what happens in their wallet.

## SDK

> ⚠️ **Alpha / Active development — 0.0.1-alpha**
>
> This is an experimental Swift interface, not a production integration. Names,
> types and behavior may change before a stable release.

This alpha includes an agent interface, typed events, transaction request/result
envelopes, and an in-memory preview for prototyping host applications. It has no
third-party package dependencies.

**A public RHYTHM network transport is not available in this release.** The default
agent throws `RhythmError.publicAPIUnavailable`. The preview makes no network calls,
does not invoke AI, and cannot read balances, sign, approve or submit transactions.
There are no API credentials to configure for the preview.

## Requirements

- Swift 5.9 or later
- iOS 15 or later
- macOS 12 or later

These deployment targets are declared in `Package.swift`. Xcode is needed for iOS
builds. Run `swift test` to exercise the package's local behavior; CI also builds
for the iOS Simulator.

## Installation

In Xcode, choose **File → Add Package Dependencies** and enter:

```text
https://github.com/Rhythmak/ios-rhythm-sdk
```

Select the `Rhythm` library. For a Swift package, add the dependency and product:

```swift
dependencies: [
    .package(url: "https://github.com/Rhythmak/ios-rhythm-sdk", branch: "main")
]

// Inside your application's target dependencies:
.product(name: "Rhythm", package: "ios-rhythm-sdk")
```

## Usage

The examples below run **locally using the preview**, not against production RHYTHM.
Place the asynchronous calls inside an async function or a `Task` in your app.

### Setup

```swift
import Rhythm

let preview = RhythmPreviewTransport()
let agent = RhythmAgentBuilder.shared.build(
    network: .robinhoodChain,
    transport: preview
)
```

`RhythmNetwork` identifies Ethereum Mainnet (chain 1) and Robinhood Chain (chain
4663). Selecting a network only sets context; it does not connect to an RPC or
change a user's wallet network.

### Listen for events

Start one event consumer per agent before connecting. Dispatch UI updates to your
app's main actor as needed.

```swift
let listener = Task {
    for await event in agent.events {
        switch event {
        case .connected(let network):
            print("Preview connected to chain \(network.rawValue)")
        case .message(let text):
            print(text) // Local preview echo; not an AI response.
        case .transactionRequested(let request):
            // Preview example: explicitly decline instead of signing anything.
            try await agent.submit(result: .init(
                requestID: request.id,
                status: .declined
            ))
        case .transactionResult:
            print("Host result received by the preview")
        case .disconnected:
            print("Preview session ended")
        }
    }
}

try await agent.connect()
```

### Send text

```swift
try await agent.send(text: "Help me understand my assets")
```

The preview returns a labeled local echo. Empty messages are rejected.

### Handle a transaction request

Inject a fictional request to test the event handler above:

```swift
let request = RhythmTransactionRequest(
    network: .robinhoodChain,
    summary: "Preview a wallet action for user review"
)
try await preview.previewTransactionRequest(request)
```

The request envelope is **not a signable transaction**. It contains an identifier,
network and display summary. No transaction schema or execution infrastructure is
provided in this alpha. A future host integration must obtain and independently
validate complete transaction details through a trusted flow, present them to the
user, and handle authorization/signing in its own wallet integration.

The host can report `.declined`, `.failed(reason:)`, or
`.submitted(transactionHash:)` using `agent.submit(result:)`. A submitted hash is
the host's report, not confirmation that a transaction succeeded. Never put wallet
credentials or sensitive data into messages, summaries or failure reasons.

The preview correlates results with pending request IDs, rejects duplicate results
and wrong-network requests, and never executes any action.

### End a session

```swift
await agent.disconnect()
try await listener.value
```

Disconnect finishes the event stream. Create a new preview and agent for a new
session. Preview events are kept in memory until consumed; this is a small
development aid, not a transport intended for sustained production traffic.

### Future transports

`RhythmAgentTransport` is an experimental adapter boundary for connect, events,
text, host results and disconnect. Applications can supply their own adapter, but
this repository does not define a public server protocol or authenticate against
the RHYTHM website. An official network adapter will require a separately published
API contract. Do not use internal website routes as an SDK API.

## UI

Chat UI components are planned and experimental. No SwiftUI views or ready-made
chat screens ship in this version. The event interface can be used to prototype
your own UI with the local preview.

## Links

- Website: [rhythm.casa](https://rhythm.casa)
- X: [@Rhythmsak](https://x.com/Rhythmsak)
