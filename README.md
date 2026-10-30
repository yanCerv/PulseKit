# PulseKit

**PulseKit** is a privacy-first, local-first telemetry and diagnostics SDK for
Swift applications on Apple platforms.

It helps developers understand how an app behaves in the real world: which
flows are used, how long operations take, where errors occur, and whether a
release is healthy. It deliberately starts small. PulseKit is not a Firebase
or a full hosted observability platform; it is a clear, dependable foundation
for collecting useful diagnostics without transmitting sensitive user data by
default.

## What it is for

Typical uses include:

- Measuring a purchase funnel: product selection → checkout → payment → result.
- Timing operations such as order creation, camera capture, or audio loading.
- Recording handled errors and lightweight crash breadcrumbs.
- Diagnosing permission failures, slow operations, and feature adoption.
- Saving diagnostics locally for development, QA, support, or a user-approved
  export.

For example, TicketSeller can record checkout states and API latency without
ever storing card details, email addresses, or other PII. PetPulse can capture
camera permissions, analysis duration, and processing errors. A music app can
measure sound loading and playback latency.

## Principles

1. **Private by default.** No network traffic is required or enabled by
   default. The initial API is designed for safe, technical metadata only.
2. **Local-first.** Events currently go to the Xcode console, making the SDK
   useful before any service exists. Local JSONL export is planned.
3. **Explicit configuration.** Sampling, environments, persistence, exporters,
   and redaction rules are opt-in and visible in app code.
4. **Small, stable public API.** The SDK should be simple to integrate and
   careful about source and binary compatibility.
5. **Useful diagnostics, not surveillance.** Collect technical context that
   improves an app; avoid identifying people.

## Installation

Add PulseKit to an iOS app in Xcode via **File → Add Package Dependencies…**
and enter:

```
https://github.com/yanCerv/PulseKit.git
```

Select **Up to Next Major Version** starting at `0.1.0`, then add the
`PulseKit` library to the app target.

## Configure PulseKit

Import and configure PulseKit once during application startup, before making
service calls. A SwiftUI app can do this in its `App` initializer:

```swift
import PulseKit

@main
struct TicketSellerApp: App {
    init() {
        PulseKit.configure(
            .init(
                environment: .production,
                sampleRate: 1.0
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

| Setting | Purpose | Default |
| --- | --- | --- |
| `environment` | Labels the source of diagnostics: `.development`, `.staging`, `.production`, or `.custom("…")`. | Required |
| `isEnabled` | Turns PulseKit recording on or off. | `true` |
| `sampleRate` | Records a proportion from `0` to `1` of eligible events. Values outside that range are clamped. | `1` |
| `deviceContext` | Reserves the policy for future technical device context collection. No device context is emitted in `0.1.0`. | `.basic` |
| `installationIdentifier` | Reserves the policy for future resettable installation correlation. Events currently use a random session ID only. | `.sessionOnly` |
| `exporters` | Destinations that receive events. | `[ConsoleExporter()]` |

`ConsoleExporter` is the default and prints structured diagnostics to the
Xcode console. PulseKit does not send data to a server.

## Log service diagnostics

Use `PulseKit.track` at service boundaries: failed network responses, retries,
unexpected decoding failures, or an operation that needs attention. It returns
the emitted `PulseEvent`, or `nil` when recording is disabled or an event is
not selected by sampling.

```swift
@discardableResult
func recordFailedOrderRequest(statusCode: Int, retryAttempt: Int) -> PulseEvent? {
    PulseKit.track(
        "order_creation_failed",
        service: "OrdersAPI",
        operation: "POST /orders",
        level: .error,
        metadata: [
            "http_status": String(statusCode),
            "retry_attempt": String(retryAttempt),
            "error_code": "service_unavailable"
        ]
    )
}
```

The public logging method is:

```swift
@discardableResult
PulseKit.track(
    _ name: String,
    service: String? = nil,
    operation: String? = nil,
    level: PulseLevel = .info,
    metadata: [String: String] = [:]
) -> PulseEvent?
```

Use stable, non-identifying values:

- `name`: an action-oriented identifier such as `request_failed` or
  `payment_authorization_failed`.
- `service`: the technical dependency, such as `OrdersAPI` or `PaymentsAPI`.
- `operation`: an HTTP method and templated path, such as `POST /orders`.
- `level`: `.debug`, `.info`, `.warning`, or `.error`.
- `metadata`: status codes, internal error codes, retry counts, or feature
  flags represented as strings.

Every event includes a UUID, timestamp, severity, random session ID, service,
operation, and metadata. The console output is deterministic enough to filter
by `event=`, `service=`, `operation=`, or `session=`.

## Privacy rules

Do not put any of the following in `metadata`, `service`, `operation`, or an
event name:

- Names, email addresses, phone numbers, account IDs, or other user data.
- Access tokens, cookies, authorization headers, API keys, or passwords.
- HTTP request/response bodies or a full URL with query parameters.
- Device serial numbers, advertising identifiers, or device names.

Use a stable internal `error_code`, HTTP status, retry count, and a templated
operation path instead. Automatic metadata redaction and JSONL local-file
export are planned future work; callers are responsible for respecting these
rules in `0.1.0`.

## First release scope

- Structured events and timed spans.
- Severity-aware diagnostic messages and handled-error recording.
- Configurable sampling and key-based redaction.
- Console and local JSON Lines (`.jsonl`) exporters.
- An in-memory queue, with optional durable local storage.
- Deterministic unit tests for ordering, redaction, concurrency, and export.
- Distribution through Swift Package Manager, followed by an XCFramework
  portfolio release.

Crash reporting can be explored later. In the initial release, PulseKit should
focus on breadcrumbs and errors that an app can safely record itself rather
than attempting to replace a mature crash-reporting service.

## Reading exported logs: PulseKit Viewer

Local JSONL logs make a lightweight companion web app possible: **PulseKit
Viewer**. The viewer would run entirely in the browser and let a developer drag
and drop one or more exported log files. It can provide:

- Timeline and searchable event table.
- Span duration waterfall and slow-operation highlighting.
- Error and breadcrumb grouping.
- Filters by app version, build, environment, event name, and date range.
- A privacy-preserving local workflow: files stay in the browser unless the
  developer explicitly chooses to upload them somewhere.

The recommended initial stack is deliberately boring:

| Need | Recommended tool | Why |
| --- | --- | --- |
| Viewer UI | React + TypeScript + Vite | Fast, well-supported static app tooling. |
| UI primitives | Tailwind CSS + a small accessible component set | Consistent layout without custom design-system overhead. |
| File parsing | Browser `File` API and a streaming JSONL parser | Keeps diagnostics on-device and handles larger files. |
| Charts | Observable Plot or ECharts | Good timelines and duration distributions without building charts from scratch. |
| Validation | Zod | Safely validates an evolving log schema. |
| Tests | Vitest + Playwright | Unit coverage for parsing and end-to-end coverage for import/filtering. |
| Hosting | GitHub Pages, Cloudflare Pages, or Vercel | A static viewer needs no backend. |

No database, authentication, or server is necessary for Viewer v1. A future
optional ingestion service could be added only after the local file format and
privacy model are proven.

## Product boundary

PulseKit aims to be a simpler, local-first cousin of Crashlytics: diagnostics
and observability for Swift apps, with an intentionally modest footprint and
privacy-first defaults. It does not initially include advertising, payments,
AI features, analytics profiling, or a proprietary backend.

## Roadmap

1. Build the Swift package and its local exporters.
2. Define and version the JSONL event schema.
3. Integrate it in TicketSeller and PetPulse.
4. Build the static Viewer around real exported logs.
5. Add release automation, compatibility documentation, changelog, and an
   XCFramework distribution example.
