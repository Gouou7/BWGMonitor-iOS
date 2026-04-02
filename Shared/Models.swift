import Foundation

public struct ServerGroupRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct ServerRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var groupID: UUID?
    public var name: String
    public var veid: String
    public var apiKey: String
    public var note: String

    public init(
        id: String,
        groupID: UUID?,
        name: String,
        veid: String,
        apiKey: String,
        note: String
    ) {
        self.id = id
        self.groupID = groupID
        self.name = name
        self.veid = veid
        self.apiKey = apiKey
        self.note = note
    }
}

public struct ServerConfiguration: Codable, Hashable, Sendable {
    public var groups: [ServerGroupRecord]
    public var servers: [ServerRecord]

    public init(groups: [ServerGroupRecord] = [], servers: [ServerRecord] = []) {
        self.groups = groups
        self.servers = servers
    }
}

public enum JSONValue: Decodable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
        }
    }

    public var stringValue: String? {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            return value.rounded() == value ? String(Int64(value)) : String(value)
        case let .bool(value):
            return value ? "true" : "false"
        case let .array(values):
            let parts = values.compactMap(\.stringValue)
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        case let .object(values):
            if let preferred = values["held"]?.stringValue ?? values["value"]?.stringValue ?? values["current"]?.stringValue {
                return preferred
            }
            return values.values.compactMap(\.stringValue).first
        case .null:
            return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case let .number(value):
            return value
        case let .string(value):
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        case let .bool(value):
            return value ? 1 : 0
        case let .array(values):
            return values.compactMap(\.doubleValue).first
        case let .object(values):
            for key in ["held", "current", "usage", "used", "value", "barrier", "softlimit", "hardlimit"] {
                if let value = values[key]?.doubleValue {
                    return value
                }
            }
            return values.values.compactMap(\.doubleValue).first
        case .null:
            return nil
        }
    }

    public var int64Value: Int64? {
        guard let doubleValue else { return nil }
        return Int64(doubleValue.rounded())
    }

    public var boolValue: Bool? {
        switch self {
        case let .bool(value):
            return value
        case let .number(value):
            return value != 0
        case let .string(value):
            switch value.lowercased() {
            case "1", "true", "yes", "running":
                return true
            case "0", "false", "no", "stopped":
                return false
            default:
                return nil
            }
        case .array, .object, .null:
            return nil
        }
    }

    public var arrayValue: [JSONValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    public var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }
}

public struct UsageSample: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let cpuUsagePercent: Double
    public let bandwidthUsedBytes: Int64
    public let bandwidthTotalBytes: Int64
    public let bandwidthRemainingBytes: Int64
    public let memoryUsedBytes: Int64
    public let memoryTotalBytes: Int64
    public let swapUsedBytes: Int64
    public let swapTotalBytes: Int64
    public let diskUsedBytes: Int64
    public let diskTotalBytes: Int64

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        cpuUsagePercent: Double,
        bandwidthUsedBytes: Int64,
        bandwidthTotalBytes: Int64 = 0,
        bandwidthRemainingBytes: Int64 = 0,
        memoryUsedBytes: Int64 = 0,
        memoryTotalBytes: Int64 = 0,
        swapUsedBytes: Int64 = 0,
        swapTotalBytes: Int64 = 0,
        diskUsedBytes: Int64 = 0,
        diskTotalBytes: Int64 = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cpuUsagePercent = cpuUsagePercent
        self.bandwidthUsedBytes = bandwidthUsedBytes
        self.bandwidthTotalBytes = bandwidthTotalBytes
        self.bandwidthRemainingBytes = bandwidthRemainingBytes
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.swapUsedBytes = swapUsedBytes
        self.swapTotalBytes = swapTotalBytes
        self.diskUsedBytes = diskUsedBytes
        self.diskTotalBytes = diskTotalBytes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case cpuUsagePercent
        case bandwidthUsedBytes
        case bandwidthTotalBytes
        case bandwidthRemainingBytes
        case memoryUsedBytes
        case memoryTotalBytes
        case swapUsedBytes
        case swapTotalBytes
        case diskUsedBytes
        case diskTotalBytes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        cpuUsagePercent = try container.decode(Double.self, forKey: .cpuUsagePercent)
        bandwidthUsedBytes = try container.decodeIfPresent(Int64.self, forKey: .bandwidthUsedBytes) ?? 0
        bandwidthTotalBytes = try container.decodeIfPresent(Int64.self, forKey: .bandwidthTotalBytes) ?? 0
        bandwidthRemainingBytes = try container.decodeIfPresent(Int64.self, forKey: .bandwidthRemainingBytes) ?? 0
        memoryUsedBytes = try container.decodeIfPresent(Int64.self, forKey: .memoryUsedBytes) ?? 0
        memoryTotalBytes = try container.decodeIfPresent(Int64.self, forKey: .memoryTotalBytes) ?? 0
        swapUsedBytes = try container.decodeIfPresent(Int64.self, forKey: .swapUsedBytes) ?? 0
        swapTotalBytes = try container.decodeIfPresent(Int64.self, forKey: .swapTotalBytes) ?? 0
        diskUsedBytes = try container.decodeIfPresent(Int64.self, forKey: .diskUsedBytes) ?? 0
        diskTotalBytes = try container.decodeIfPresent(Int64.self, forKey: .diskTotalBytes) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(cpuUsagePercent, forKey: .cpuUsagePercent)
        try container.encode(bandwidthUsedBytes, forKey: .bandwidthUsedBytes)
        try container.encode(bandwidthTotalBytes, forKey: .bandwidthTotalBytes)
        try container.encode(bandwidthRemainingBytes, forKey: .bandwidthRemainingBytes)
        try container.encode(memoryUsedBytes, forKey: .memoryUsedBytes)
        try container.encode(memoryTotalBytes, forKey: .memoryTotalBytes)
        try container.encode(swapUsedBytes, forKey: .swapUsedBytes)
        try container.encode(swapTotalBytes, forKey: .swapTotalBytes)
        try container.encode(diskUsedBytes, forKey: .diskUsedBytes)
        try container.encode(diskTotalBytes, forKey: .diskTotalBytes)
    }
}

public struct ServerSnapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var groupName: String?
    public var displayName: String
    public var note: String
    public var location: String
    public var vmType: String
    public var status: String
    public var ipAddresses: [String]
    public var monthlyTransferTotalBytes: Int64
    public var monthlyTransferUsedBytes: Int64
    public var nextReset: Date
    public var cpuUsagePercent: Double
    public var memoryUsedBytes: Int64
    public var memoryTotalBytes: Int64
    public var swapUsedBytes: Int64
    public var swapTotalBytes: Int64
    public var diskUsedBytes: Int64
    public var diskTotalBytes: Int64
    public var loadAverage: String
    public var history: [UsageSample]
    public var updatedAt: Date

    public init(
        id: String,
        groupName: String?,
        displayName: String,
        note: String,
        location: String,
        vmType: String,
        status: String,
        ipAddresses: [String],
        monthlyTransferTotalBytes: Int64,
        monthlyTransferUsedBytes: Int64,
        nextReset: Date,
        cpuUsagePercent: Double,
        memoryUsedBytes: Int64,
        memoryTotalBytes: Int64,
        swapUsedBytes: Int64,
        swapTotalBytes: Int64,
        diskUsedBytes: Int64,
        diskTotalBytes: Int64,
        loadAverage: String,
        history: [UsageSample],
        updatedAt: Date
    ) {
        self.id = id
        self.groupName = groupName
        self.displayName = displayName
        self.note = note
        self.location = location
        self.vmType = vmType
        self.status = status
        self.ipAddresses = ipAddresses
        self.monthlyTransferTotalBytes = monthlyTransferTotalBytes
        self.monthlyTransferUsedBytes = monthlyTransferUsedBytes
        self.nextReset = nextReset
        self.cpuUsagePercent = cpuUsagePercent
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.swapUsedBytes = swapUsedBytes
        self.swapTotalBytes = swapTotalBytes
        self.diskUsedBytes = diskUsedBytes
        self.diskTotalBytes = diskTotalBytes
        self.loadAverage = loadAverage
        self.history = history
        self.updatedAt = updatedAt
    }

    public var monthlyTransferRemainingBytes: Int64 {
        max(0, monthlyTransferTotalBytes - monthlyTransferUsedBytes)
    }

    public var memoryUsageFraction: Double {
        Self.fraction(used: memoryUsedBytes, total: memoryTotalBytes)
    }

    public var swapUsageFraction: Double {
        Self.fraction(used: swapUsedBytes, total: swapTotalBytes)
    }

    public var diskUsageFraction: Double {
        Self.fraction(used: diskUsedBytes, total: diskTotalBytes)
    }

    private static func fraction(used: Int64, total: Int64) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }

    public var withoutHistory: ServerSnapshot {
        var copy = self
        copy.history = []
        return copy
    }
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var language: AppLanguage
    public var historyRetentionDays: Int
    public var autoRefreshIntervalMinutes: Int
    public var launchAtLogin: Bool
    public var launchToMenuBarOnly: Bool
    public var hideDockIcon: Bool
    public var menuBarUsesCustomServers: Bool
    public var menuBarServerIDs: [String]

    public init(
        language: AppLanguage = .system,
        historyRetentionDays: Int = 30,
        autoRefreshIntervalMinutes: Int = 0,
        launchAtLogin: Bool = false,
        launchToMenuBarOnly: Bool = false,
        hideDockIcon: Bool = false,
        menuBarUsesCustomServers: Bool = false,
        menuBarServerIDs: [String] = []
    ) {
        self.language = language
        self.historyRetentionDays = historyRetentionDays
        self.autoRefreshIntervalMinutes = autoRefreshIntervalMinutes
        self.launchAtLogin = launchAtLogin
        self.launchToMenuBarOnly = launchToMenuBarOnly
        self.hideDockIcon = hideDockIcon
        self.menuBarUsesCustomServers = menuBarUsesCustomServers
        self.menuBarServerIDs = menuBarServerIDs
    }

    enum CodingKeys: String, CodingKey {
        case language
        case historyRetentionDays
        case autoRefreshIntervalMinutes
        case launchAtLogin
        case launchToMenuBarOnly
        case hideDockIcon
        case menuBarUsesCustomServers
        case menuBarServerIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        historyRetentionDays = try container.decodeIfPresent(Int.self, forKey: .historyRetentionDays) ?? 30
        autoRefreshIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .autoRefreshIntervalMinutes) ?? 0
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        launchToMenuBarOnly = try container.decodeIfPresent(Bool.self, forKey: .launchToMenuBarOnly) ?? false
        hideDockIcon = try container.decodeIfPresent(Bool.self, forKey: .hideDockIcon) ?? false
        menuBarUsesCustomServers = try container.decodeIfPresent(Bool.self, forKey: .menuBarUsesCustomServers) ?? false
        menuBarServerIDs = try container.decodeIfPresent([String].self, forKey: .menuBarServerIDs) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language, forKey: .language)
        try container.encode(historyRetentionDays, forKey: .historyRetentionDays)
        try container.encode(autoRefreshIntervalMinutes, forKey: .autoRefreshIntervalMinutes)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(launchToMenuBarOnly, forKey: .launchToMenuBarOnly)
        try container.encode(hideDockIcon, forKey: .hideDockIcon)
        try container.encode(menuBarUsesCustomServers, forKey: .menuBarUsesCustomServers)
        try container.encode(menuBarServerIDs, forKey: .menuBarServerIDs)
    }
}

public enum AppLanguage: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case system
    case english
    case simplifiedChinese

    public var id: String { rawValue }
}

public struct ServiceInfoResponse: Decodable, Sendable {
    public let vmType: String?
    public let hostname: String?
    public let nodeAlias: String?
    public let nodeLocation: String?
    public let plan: String?
    public let planMonthlyData: Int64?
    public let planDisk: Int64?
    public let planRam: Int64?
    public let planSwap: Int64?
    public let dataCounter: Int64?
    public let monthlyDataMultiplier: Double?
    public let dataNextReset: TimeInterval?
    public let ipAddresses: [String]?
    public let privateIpAddresses: [String]?
    public let suspended: Bool?
    public let error: Int
    public let message: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        vmType = container.decodeFlexibleString("vm_type")
        hostname = container.decodeFlexibleString("hostname")
        nodeAlias = container.decodeFlexibleString("node_alias")
        nodeLocation = container.decodeFlexibleString("node_location")
        plan = container.decodeFlexibleString("plan")
        planMonthlyData = container.decodeFlexibleInt64("plan_monthly_data")
        planDisk = container.decodeFlexibleInt64("plan_disk")
        planRam = container.decodeFlexibleInt64("plan_ram")
        planSwap = container.decodeFlexibleInt64("plan_swap")
        dataCounter = container.decodeFlexibleInt64("data_counter")
        monthlyDataMultiplier = container.decodeFlexibleDouble("monthly_data_multiplier")
        dataNextReset = container.decodeFlexibleDouble("data_next_reset")
        ipAddresses = container.decodeFlexibleStringArray("ip_addresses")
        privateIpAddresses = container.decodeFlexibleStringArray("private_ip_addresses")
        suspended = container.decodeFlexibleBool("suspended")
        error = container.decodeFlexibleInt("error") ?? 0
        message = container.decodeFlexibleString("message")
    }
}

public struct LiveServiceInfoResponse: Decodable, Sendable {
    public let serviceInfo: ServiceInfoResponse
    public let vzStatus: [String: JSONValue]?
    public let vzQuota: [String: JSONValue]?
    public let veStatus: String?
    public let usedDiskSpaceBytes: Int64?
    public let diskQuotaGB: Int64?
    public let isCPUThrottled: Int?
    public let isDiskThrottled: Int?
    public let sshPort: Int?
    public let liveHostname: String?
    public let loadAverage: String?
    public let cpuUsagePercent: Double?
    public let memoryAvailableKB: Int64?
    public let swapTotalKB: Int64?
    public let swapAvailableKB: Int64?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        serviceInfo = try ServiceInfoResponse(from: decoder)
        vzStatus = container.decodeFlexibleObject("vz_status")
        vzQuota = container.decodeFlexibleObject("vz_quota")
        veStatus = container.decodeFlexibleString("ve_status")
        usedDiskSpaceBytes = container.decodeFlexibleInt64("ve_used_disk_space_b")
        diskQuotaGB = container.decodeFlexibleInt64("ve_disk_quota_gb")
        isCPUThrottled = container.decodeFlexibleInt("is_cpu_throttled")
        isDiskThrottled = container.decodeFlexibleInt("is_disk_throttled")
        sshPort = container.decodeFlexibleInt("ssh_port")
        liveHostname = container.decodeFlexibleString("live_hostname")
        loadAverage = container.decodeFlexibleString("load_average")
        cpuUsagePercent = container.decodeFlexibleDouble("cpu_usage_percent")
            ?? container.decodeFlexibleDouble("cpu_percent")
            ?? container.decodeFlexibleDouble("cpu_usage")
            ?? container.decodeFlexibleDouble("cpu")
        memoryAvailableKB = container.decodeFlexibleInt64("mem_available_kb")
        swapTotalKB = container.decodeFlexibleInt64("swap_total_kb")
        swapAvailableKB = container.decodeFlexibleInt64("swap_available_kb")
    }
}

public struct MutationResponse: Decodable, Sendable {
    public let error: Int
    public let message: String?
}

public struct RateLimitStatusResponse: Decodable, Sendable {
    public let remainingPoints15m: Int?
    public let remainingPoints24h: Int?
    public let error: Int

    enum CodingKeys: String, CodingKey {
        case remainingPoints15m = "remaining_points_15min"
        case remainingPoints24h = "remaining_points_24h"
        case error
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == DynamicCodingKey {
    func decodeFlexibleValue(_ key: String) -> JSONValue? {
        try? decodeIfPresent(JSONValue.self, forKey: DynamicCodingKey(key))
    }

    func decodeFlexibleString(_ key: String) -> String? {
        decodeFlexibleValue(key)?.stringValue
    }

    func decodeFlexibleInt64(_ key: String) -> Int64? {
        decodeFlexibleValue(key)?.int64Value
    }

    func decodeFlexibleInt(_ key: String) -> Int? {
        decodeFlexibleInt64(key).map(Int.init)
    }

    func decodeFlexibleDouble(_ key: String) -> Double? {
        decodeFlexibleValue(key)?.doubleValue
    }

    func decodeFlexibleBool(_ key: String) -> Bool? {
        decodeFlexibleValue(key)?.boolValue
    }

    func decodeFlexibleObject(_ key: String) -> [String: JSONValue]? {
        decodeFlexibleValue(key)?.objectValue
    }

    func decodeFlexibleStringArray(_ key: String) -> [String]? {
        guard let value = decodeFlexibleValue(key) else { return nil }

        switch value {
        case let .array(values):
            return values.compactMap(\.stringValue)
        case let .string(value):
            return [value]
        default:
            return nil
        }
    }
}
