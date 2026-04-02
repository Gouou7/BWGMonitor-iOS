import Foundation

public enum KiwiVMUsageStatsParser {
    public static func parse(_ value: JSONValue) -> [UsageSample] {
        var samples: [UsageSample] = []
        collectSamples(from: value, into: &samples)

        return Dictionary(grouping: samples, by: { $0.timestamp.timeIntervalSince1970 })
            .compactMap { _, values in values.max(by: { $0.cpuUsagePercent < $1.cpuUsagePercent }) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private static func collectSamples(from value: JSONValue, into samples: inout [UsageSample]) {
        if let sample = parseRow(from: value) {
            samples.append(sample)
            return
        }

        switch value {
        case let .array(values):
            values.forEach { collectSamples(from: $0, into: &samples) }
        case let .object(object):
            object.values.forEach { collectSamples(from: $0, into: &samples) }
        case .string, .number, .bool, .null:
            break
        }
    }

    private static func parseRow(from value: JSONValue) -> UsageSample? {
        switch value {
        case let .array(values):
            return parseArrayRow(values)
        case let .object(object):
            return parseObjectRow(object)
        case .string, .number, .bool, .null:
            return nil
        }
    }

    private static func parseArrayRow(_ row: [JSONValue]) -> UsageSample? {
        let numericValues = row.compactMap(\.doubleValue)
        guard let timestamp = normalizedTimestamp(from: numericValues.first) else {
            return nil
        }

        let tail = Array(numericValues.dropFirst())
        let cpu = preferredCPU(from: tail) ?? inferredCPU(from: tail)
        let bandwidth = tail.filter { $0 > 1_000 }.reduce(0, +)

        return UsageSample(
            timestamp: timestamp,
            cpuUsagePercent: cpu,
            bandwidthUsedBytes: Int64(bandwidth.rounded())
        )
    }

    private static func parseObjectRow(_ row: [String: JSONValue]) -> UsageSample? {
        let timestamp = row["timestamp"]?.doubleValue
            ?? row["time"]?.doubleValue
            ?? row["date"]?.doubleValue
            ?? row["x"]?.doubleValue

        guard let normalized = normalizedTimestamp(from: timestamp) else {
            return nil
        }

        let cpu = row["cpu_usage_percent"]?.doubleValue
            ?? row["cpu_percent"]?.doubleValue
            ?? row["cpu_usage"]?.doubleValue
            ?? row["cpu"]?.doubleValue
            ?? row["percent"]?.doubleValue
            ?? preferredCPU(from: row.values.compactMap(\.doubleValue))
            ?? inferredCPU(from: row.values.compactMap(\.doubleValue))

        let bandwidth = [
            row["network_in_bytes"]?.doubleValue,
            row["network_out_bytes"]?.doubleValue,
            row["netin"]?.doubleValue,
            row["netout"]?.doubleValue,
            row["bandwidth_used_bytes"]?.doubleValue,
        ]
        .compactMap { $0 }
        .reduce(0, +)

        return UsageSample(
            timestamp: normalized,
            cpuUsagePercent: cpu,
            bandwidthUsedBytes: Int64(bandwidth.rounded())
        )
    }

    private static func normalizedTimestamp(from raw: Double?) -> Date? {
        guard let raw else { return nil }

        if raw > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: raw / 1000)
        }

        if raw > 1_000_000_000 {
            return Date(timeIntervalSince1970: raw)
        }

        return nil
    }

    private static func inferredCPU(from numericValues: [Double]) -> Double {
        preferredCPU(from: numericValues) ?? 0
    }

    private static func preferredCPU(from numericValues: [Double]) -> Double? {
        let candidates = numericValues.filter { 0 ... 100 ~= $0 }
        if let positive = candidates.last(where: { $0 > 0 }) {
            return positive
        }

        return candidates.last
    }
}
