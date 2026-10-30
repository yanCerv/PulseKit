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
   default. Sensitive keys are redacted before an event is stored or exported.
2. **Local-first.** Events can go to the Xcode console or a local JSONL file,
   making the SDK useful before any service exists.
3. **Explicit configuration.** Sampling, environments, persistence, exporters,
   and redaction rules are opt-in and visible in app code.
4. **Small, stable public API.** The SDK should be simple to integrate and
   careful about source and binary compatibility.
5. **Useful diagnostics, not surveillance.** Collect technical context that
   improves an app; avoid identifying people.

## Intended API

```swift
import PulseKit

PulseKit.configure(
    .init(environment: .development, exporters: [.console, .localFile])
)

PulseKit.track("checkout_started", metadata: [
    "payment_method": "apple_pay"
])

let span = PulseKit.startSpan("create_order")
defer { span.finish() }

// Perform asynchronous or synchronous work.
```

The first public building blocks will be `PulseEvent`, `PulseSpan`,
`PulseConfiguration`, and interchangeable exporters.

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
