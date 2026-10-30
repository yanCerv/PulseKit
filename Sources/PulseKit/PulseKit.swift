import Foundation

/// The runtime configuration for PulseKit.
///
/// PulseKit deliberately accepts only technical diagnostics settings here.
/// It does not configure user identity, credentials, request bodies, or other
/// personal data collection.
public struct PulseConfiguration: Sendable {
    /// Identifies the app environment that emitted a diagnostic.
    public var environment: PulseEnvironment
    /// Enables or disables all PulseKit recording.
    public var isEnabled: Bool
    /// The proportion of eligible diagnostics to record, from `0` through `1`.
    public var sampleRate: Double
    /// Controls whether basic technical device context is attached to a log.
    public var deviceContext: DeviceContextPolicy
    /// Controls the scope of the non-user identifier attached to a log.
    public var installationIdentifier: InstallationIdentifierPolicy
    /// Receives diagnostics after they are recorded.
    public var exporters: [any PulseExporting]

    public init(
        environment: PulseEnvironment,
        isEnabled: Bool = true,
        sampleRate: Double = 1,
        deviceContext: DeviceContextPolicy = .basic,
        installationIdentifier: InstallationIdentifierPolicy = .sessionOnly,
        exporters: [any PulseExporting] = [ConsoleExporter()]
    ) {
        self.environment = environment
        self.isEnabled = isEnabled
        self.sampleRate = min(max(sampleRate, 0), 1)
        self.deviceContext = deviceContext
        self.installationIdentifier = installationIdentifier
        self.exporters = exporters
    }

    /// A safe default for local development.
    public static let development = PulseConfiguration(environment: .development)
}

/// The app environment associated with a diagnostic event.
public enum PulseEnvironment: Sendable, Equatable {
    case development
    case staging
    case production
    case custom(String)
}

/// The amount of device context attached to a diagnostic event.
public enum DeviceContextPolicy: Sendable, Equatable {
    /// Do not attach device information.
    case none
    /// Attach technical context such as OS version, device model, app version,
    /// and build number. Device names, serial numbers, and advertising IDs are
    /// never collected.
    case basic
}

/// The scope of the random identifier used to correlate diagnostics.
public enum InstallationIdentifierPolicy: Sendable, Equatable {
    /// Create a new random identifier for every app session.
    case sessionOnly
    /// Persist a random, resettable identifier locally on the device. This is
    /// intended only for developer-approved diagnostic exports.
    case persistentLocal
}

/// Configures the PulseKit diagnostics runtime.
public enum PulseKit {
    private static let configurationStore = ConfigurationStore()
    private static let sessionID = UUID()

    /// Replaces the active runtime configuration.
    public static func configure(_ configuration: PulseConfiguration) {
        configurationStore.set(configuration)
    }

    /// Returns the current runtime configuration.
    public static var configuration: PulseConfiguration {
        configurationStore.get()
    }

    /// Records a service diagnostic and sends it to the configured exporters.
    ///
    /// Keep metadata limited to safe operational values such as status codes,
    /// retry counts, and internal error codes. Do not include HTTP headers,
    /// request bodies, credentials, or user information.
    @discardableResult
    public static func track(
        _ name: String,
        service: String? = nil,
        operation: String? = nil,
        level: PulseLevel = .info,
        metadata: [String: String] = [:]
    ) -> PulseEvent? {
        let configuration = configurationStore.get()

        guard configuration.isEnabled, shouldSample(rate: configuration.sampleRate) else {
            return nil
        }

        let event = PulseEvent(
            timestamp: Date(),
            name: name,
            level: level,
            service: service,
            operation: operation,
            sessionID: sessionID,
            metadata: metadata
        )

        configuration.exporters.forEach { $0.export(event) }
        return event
    }

    private static func shouldSample(rate: Double) -> Bool {
        switch rate {
        case ...0:
            return false
        case 1...:
            return true
        default:
            return Double.random(in: 0..<1) < rate
        }
    }
}

/// A structured diagnostic record emitted by PulseKit.
public struct PulseEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let name: String
    public let level: PulseLevel
    public let service: String?
    public let operation: String?
    public let sessionID: UUID
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        name: String,
        level: PulseLevel = .info,
        service: String? = nil,
        operation: String? = nil,
        sessionID: UUID,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.name = name
        self.level = level
        self.service = service
        self.operation = operation
        self.sessionID = sessionID
        self.metadata = metadata
    }
}

/// The severity of a diagnostic event.
public enum PulseLevel: String, Codable, Sendable, Equatable {
    case debug
    case info
    case warning
    case error
}

/// A destination that receives PulseKit diagnostic events.
public protocol PulseExporting: Sendable {
    func export(_ event: PulseEvent)
}

/// Prints a concise, structured representation of each event to the console.
public struct ConsoleExporter: PulseExporting {
    public init() {}

    public func export(_ event: PulseEvent) {
        var fields = [
            "timestamp=\(event.timestamp.ISO8601Format())",
            "level=\(event.level.rawValue)",
            "event=\(event.name)",
            "session=\(event.sessionID.uuidString)"
        ]

        if let service = event.service {
            fields.append("service=\(service)")
        }
        if let operation = event.operation {
            fields.append("operation=\(operation)")
        }
        event.metadata.sorted { $0.key < $1.key }.forEach { key, value in
            fields.append("\(key)=\(value)")
        }

        print("PulseKit \(fields.joined(separator: " "))")
    }
}

private final class ConfigurationStore: @unchecked Sendable {
    private let lock = NSLock()
    private var value = PulseConfiguration.development

    func set(_ configuration: PulseConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        value = configuration
    }

    func get() -> PulseConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
