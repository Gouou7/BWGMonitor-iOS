import Foundation

public enum SampleData {
    public static let groups: [ServerGroupRecord] = [
        ServerGroupRecord(name: "Asia"),
        ServerGroupRecord(name: "North America"),
    ]

    public static let snapshots: [ServerSnapshot] = [
        makeSnapshot(
            id: "1978839",
            groupName: "Asia",
            name: "Tokyo KVM",
            note: "Example development box",
            location: "JP, Tokyo",
            status: "Running",
            ip: "45.12.34.56",
            transferTotal: 2_000_000_000_000,
            transferUsed: 740_000_000_000,
            cpu: 31,
            memoryUsed: 1_420_000_000,
            memoryTotal: 2_000_000_000,
            swapUsed: 120_000_000,
            swapTotal: 512_000_000,
            diskUsed: 16_400_000_000,
            diskTotal: 25_000_000_000,
            loadAverage: "0.32 0.40 0.44"
        ),
        makeSnapshot(
            id: "2084101",
            groupName: "North America",
            name: "Los Angeles KVM",
            note: "Example staging node",
            location: "US, California",
            status: "Starting",
            ip: "144.34.225.163",
            transferTotal: 1_000_000_000_000,
            transferUsed: 440_000_000_000,
            cpu: 57,
            memoryUsed: 900_000_000,
            memoryTotal: 1_500_000_000,
            swapUsed: 60_000_000,
            swapTotal: 256_000_000,
            diskUsed: 11_100_000_000,
            diskTotal: 20_000_000_000,
            loadAverage: "0.77 0.81 0.90"
        ),
    ]

    private static func makeSnapshot(
        id: String,
        groupName: String?,
        name: String,
        note: String,
        location: String,
        status: String,
        ip: String,
        transferTotal: Int64,
        transferUsed: Int64,
        cpu: Double,
        memoryUsed: Int64,
        memoryTotal: Int64,
        swapUsed: Int64,
        swapTotal: Int64,
        diskUsed: Int64,
        diskTotal: Int64,
        loadAverage: String
    ) -> ServerSnapshot {
        let now = Date()
        let history = stride(from: 11, through: 0, by: -1).map { offset in
            let timestamp = Calendar.current.date(byAdding: .hour, value: -offset * 2, to: now) ?? now
            let cpuValue = max(12, cpu - Double(offset) * 1.7)
            let bandwidthValue = transferUsed - Int64(offset) * 14_000_000_000
            let memoryValue = max(0, memoryUsed - Int64(offset) * 18_000_000)
            let swapValue = max(0, swapUsed - Int64(offset) * 4_000_000)
            let diskValue = max(0, diskUsed - Int64(offset) * 120_000_000)

            return UsageSample(
                timestamp: timestamp,
                cpuUsagePercent: cpuValue,
                bandwidthUsedBytes: bandwidthValue,
                bandwidthTotalBytes: transferTotal,
                bandwidthRemainingBytes: max(0, transferTotal - bandwidthValue),
                memoryUsedBytes: memoryValue,
                memoryTotalBytes: memoryTotal,
                swapUsedBytes: swapValue,
                swapTotalBytes: swapTotal,
                diskUsedBytes: diskValue,
                diskTotalBytes: diskTotal
            )
        }

        return ServerSnapshot(
            id: id,
            groupName: groupName,
            displayName: name,
            note: note,
            location: location,
            vmType: "kvm",
            status: status,
            ipAddresses: [ip],
            monthlyTransferTotalBytes: transferTotal,
            monthlyTransferUsedBytes: transferUsed,
            nextReset: Calendar.current.date(byAdding: .day, value: 12, to: now) ?? now,
            cpuUsagePercent: cpu,
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
}
