import Testing
import Foundation
import PulseKit

@Suite(.serialized)
struct PulseKitTests {
    @Test func configurationClampsSamplingToSupportedRange() {
        let belowRange = PulseConfiguration(environment: .development, sampleRate: -0.5)
        let aboveRange = PulseConfiguration(environment: .production, sampleRate: 1.5)

        #expect(belowRange.sampleRate == 0)
        #expect(aboveRange.sampleRate == 1)
    }

    @Test func configurationDefaultsToPrivacyPreservingSessionCorrelation() {
        let configuration = PulseConfiguration(environment: .staging)

        #expect(configuration.deviceContext == .basic)
        #expect(configuration.installationIdentifier == .sessionOnly)
    }

    @Test func pulseKitAppliesConfiguration() {
        let original = PulseKit.configuration
        defer { PulseKit.configure(original) }

        let configuration = PulseConfiguration(
            environment: .production,
            isEnabled: false,
            sampleRate: 0.25,
            deviceContext: .none,
            installationIdentifier: .persistentLocal
        )

        PulseKit.configure(configuration)

        #expect(PulseKit.configuration.environment == .production)
        #expect(PulseKit.configuration.isEnabled == false)
        #expect(PulseKit.configuration.sampleRate == 0.25)
        #expect(PulseKit.configuration.deviceContext == .none)
        #expect(PulseKit.configuration.installationIdentifier == .persistentLocal)
    }

    @Test func trackCreatesServiceEventWithSessionCorrelation() {
        let original = PulseKit.configuration
        defer { PulseKit.configure(original) }
        PulseKit.configure(.init(environment: .development, exporters: []))

        let event = PulseKit.track(
            "order_creation_failed",
            service: "OrdersAPI",
            operation: "POST /orders",
            level: .error,
            metadata: ["http_status": "503", "retry_attempt": "2"]
        )

        #expect(event?.name == "order_creation_failed")
        #expect(event?.level == .error)
        #expect(event?.service == "OrdersAPI")
        #expect(event?.operation == "POST /orders")
        #expect(event?.metadata["http_status"] == "503")
        #expect(event?.sessionID != nil)
    }

    @Test func trackSkipsEventsWhenDisabled() {
        let original = PulseKit.configuration
        defer { PulseKit.configure(original) }
        PulseKit.configure(.init(environment: .development, isEnabled: false, exporters: []))

        #expect(PulseKit.track("request_failed", level: .error) == nil)
    }

    @Test func serviceFailureIsDeliveredToAnAppConfiguredExporter() {
        let original = PulseKit.configuration
        defer { PulseKit.configure(original) }

        let recorder = EventRecorder()
        PulseKit.configure(
            .init(environment: .staging, exporters: [recorder])
        )

        // This is the same call a networking layer in TicketSeller can make
        // after receiving an unsuccessful response from a backend service.
        PulseKit.track(
            "payment_authorization_failed",
            service: "PaymentsAPI",
            operation: "POST /payments/authorize",
            level: .error,
            metadata: ["http_status": "502", "error_code": "upstream_failure"]
        )

        let events = recorder.events
        #expect(events.count == 1)
        #expect(events[0].service == "PaymentsAPI")
        #expect(events[0].operation == "POST /payments/authorize")
        #expect(events[0].level == .error)
        #expect(events[0].metadata["error_code"] == "upstream_failure")
    }
}

private final class EventRecorder: @unchecked Sendable, PulseExporting {
    private let lock = NSLock()
    private var storedEvents: [PulseEvent] = []

    var events: [PulseEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    func export(_ event: PulseEvent) {
        lock.lock()
        defer { lock.unlock() }
        storedEvents.append(event)
    }
}
