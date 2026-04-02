import Foundation

public enum KiwiVMSnapshotMapper {
    public static func makeSnapshot(
        server: ServerRecord,
        serviceInfo: ServiceInfoResponse,
        liveInfo: LiveServiceInfoResponse?,
        history: [UsageSample],
        now: Date = .now
    ) -> ServerSnapshot {
        let vmType = (serviceInfo.vmType ?? liveInfo?.serviceInfo.vmType ?? "unknown").lowercased()
        let multiplier = serviceInfo.monthlyDataMultiplier ?? 1
        let totalTransfer = Int64((Double(serviceInfo.planMonthlyData ?? 0) * multiplier).rounded())
        let usedTransfer = Int64((Double(serviceInfo.dataCounter ?? 0) * multiplier).rounded())

        let memoryTotal = serviceInfo.planRam ?? 0
        let memoryUsed: Int64 = {
            if vmType == "kvm", let memoryAvailableKB = liveInfo?.memoryAvailableKB {
                return max(0, memoryTotal - memoryAvailableKB * 1024)
            }
            return ovzMemoryUsedBytes(from: liveInfo?.vzStatus) ?? 0
        }()

        let swapTotal: Int64 = {
            if vmType == "kvm" {
                return max((liveInfo?.swapTotalKB ?? 0) * 1024, serviceInfo.planSwap ?? 0)
            }
            return max(serviceInfo.planSwap ?? 0, ovzSwapTotalBytes(from: liveInfo?.vzStatus) ?? 0)
        }()

        let swapUsed: Int64 = {
            if vmType == "kvm", let swapAvailableKB = liveInfo?.swapAvailableKB {
                return swapTotal > 0 ? max(0, swapTotal - swapAvailableKB * 1024) : 0
            }

            if let ovzSwap = ovzSwapUsedBytes(from: liveInfo?.vzStatus) {
                return ovzSwap
            }

            return 0
        }()

        let diskTotal: Int64 = {
            if let liveQuota = liveInfo?.diskQuotaGB, liveQuota > 0 {
                return max(serviceInfo.planDisk ?? 0, liveQuota * 1_073_741_824)
            }
            return serviceInfo.planDisk ?? 0
        }()

        let diskUsed = liveInfo?.usedDiskSpaceBytes ?? ovzDiskUsedBytes(from: liveInfo?.vzQuota) ?? 0
        let cpuUsage = resolvedCPUUsage(liveInfo: liveInfo, history: history)
        let status = resolvedStatus(vmType: vmType, serviceInfo: serviceInfo, liveInfo: liveInfo)
        let loadAverage = liveInfo?.loadAverage ?? liveInfo?.vzStatus?.firstString(forKeys: ["load_average", "load average", "loadavg"]) ?? "n/a"

        return ServerSnapshot(
            id: server.id,
            groupName: nil,
            displayName: server.name.isEmpty ? (liveInfo?.liveHostname ?? serviceInfo.hostname ?? server.veid) : server.name,
            note: server.note,
            location: serviceInfo.nodeLocation ?? "Unknown location",
            vmType: vmType,
            status: status,
            ipAddresses: serviceInfo.ipAddresses ?? [],
            monthlyTransferTotalBytes: totalTransfer,
            monthlyTransferUsedBytes: usedTransfer,
            nextReset: Date(timeIntervalSince1970: serviceInfo.dataNextReset ?? now.timeIntervalSince1970),
            cpuUsagePercent: cpuUsage,
            memoryUsedBytes: memoryUsed,
            memoryTotalBytes: memoryTotal,
            swapUsedBytes: swapUsed,
            swapTotalBytes: swapTotal,
            diskUsedBytes: diskUsed,
            diskTotalBytes: diskTotal,
            loadAverage: loadAverage,
            history: history,
            updatedAt: now
        )
    }

    private static func resolvedStatus(
        vmType: String,
        serviceInfo: ServiceInfoResponse,
        liveInfo: LiveServiceInfoResponse?
    ) -> String {
        if let veStatus = liveInfo?.veStatus, !veStatus.isEmpty {
            return veStatus
        }

        if serviceInfo.suspended == true {
            return "Suspended"
        }

        if vmType == "ovz", liveInfo != nil {
            return "Running"
        }

        return "Unknown"
    }

    private static func resolvedCPUUsage(
        liveInfo: LiveServiceInfoResponse?,
        history: [UsageSample]
    ) -> Double {
        if let liveCPU = liveInfo?.cpuUsagePercent {
            return clampedPercentage(liveCPU)
        }

        if let historyCPU = history.last?.cpuUsagePercent, historyCPU > 0 {
            return clampedPercentage(historyCPU)
        }

        if let loadAverage = parsedLoadAveragePercentage(from: liveInfo?.loadAverage) {
            return clampedPercentage(loadAverage)
        }

        return (liveInfo?.isCPUThrottled == 1) ? 100 : 0
    }

    private static func parsedLoadAveragePercentage(from rawValue: String?) -> Double? {
        guard
            let rawValue,
            let token = rawValue
                .split(whereSeparator: { $0 == " " || $0 == "," })
                .first,
            let value = Double(token)
        else {
            return nil
        }

        return value > 0 ? min(value * 100, 100) : nil
    }

    private static func clampedPercentage(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    private static func ovzMemoryUsedBytes(from status: [String: JSONValue]?) -> Int64? {
        guard let status else { return nil }
        for key in ["physpages", "privvmpages", "oomguarpages", "vmguarpages"] {
            if let pages = status[key]?.doubleValue {
                return Int64((pages * 4096).rounded())
            }
        }
        return nil
    }

    private static func ovzSwapUsedBytes(from status: [String: JSONValue]?) -> Int64? {
        guard let status, let pages = status["swappages"]?.doubleValue else { return nil }
        return Int64((pages * 4096).rounded())
    }

    private static func ovzSwapTotalBytes(from status: [String: JSONValue]?) -> Int64? {
        guard let status else { return nil }
        if let value = status["swappages"]?.firstSecondaryDoubleValue {
            return Int64((value * 4096).rounded())
        }
        return nil
    }

    private static func ovzDiskUsedBytes(from quota: [String: JSONValue]?) -> Int64? {
        guard let quota else { return nil }

        for key in ["diskspace", "disk_space", "space_used_kb"] {
            if let numeric = quota[key]?.doubleValue {
                return Int64((numeric * 1024).rounded())
            }
        }

        return nil
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func firstString(forKeys keys: [String]) -> String? {
        for key in keys {
            if let value = self[key]?.stringValue, !value.isEmpty {
                return value
            }
        }
        return nil
    }
}

private extension JSONValue {
    var firstSecondaryDoubleValue: Double? {
        switch self {
        case let .array(values):
            let numerics = values.compactMap(\.doubleValue)
            return numerics.count > 1 ? numerics[1] : numerics.first
        case let .object(values):
            let numerics = values.values.compactMap(\.doubleValue)
            return numerics.count > 1 ? numerics[1] : numerics.first
        default:
            return nil
        }
    }
}
