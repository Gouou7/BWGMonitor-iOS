import BWGMonitorShared
import Charts
import SwiftUI

private enum ServerMetricDetail: String, Identifiable {
    case transfer
    case cpu
    case memory
    case swap
    case disk

    var id: String { rawValue }
}

private struct MetricHistoryPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

private enum HistoryRangeUnit: String, CaseIterable, Identifiable {
    case hour
    case day
    case month

    var id: String { rawValue }
}

struct ServerDetailView: View {
    let server: ServerRecord
    let snapshot: ServerSnapshot?
    let language: AppLanguage
    let actionHandler: (PowerAction) -> Void
    let clearHistoryHandler: () -> Void

    @State private var pendingPowerAction: PowerAction?
    @State private var presentedMetric: ServerMetricDetail?

    private var strings: AppStrings {
        AppStrings(language: language)
    }

    private var powerConfirmationTitle: String {
        if let pendingPowerAction {
            return strings.confirmPowerActionTitle(pendingPowerAction)
        }
        return strings.confirmAction
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let snapshot {
                    metrics(snapshot: snapshot)
                } else {
                    ContentUnavailableView(
                        "No Live Data Yet",
                        systemImage: "waveform.path.ecg",
                        description: Text("Refresh this server to load KiwiVM status and historical metrics.")
                    )
                }

                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .confirmationDialog(
            powerConfirmationTitle,
            isPresented: Binding(
                get: { pendingPowerAction != nil },
                set: { if !$0 { pendingPowerAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingPowerAction {
                Button(strings.powerActionTitle(pendingPowerAction), role: pendingPowerAction == .stop ? .destructive : nil) {
                    actionHandler(pendingPowerAction)
                    self.pendingPowerAction = nil
                }
            }

            Button(strings.cancel, role: .cancel) {
                pendingPowerAction = nil
            }
        } message: {
            if let pendingPowerAction {
                Text(strings.confirmPowerActionMessage(pendingPowerAction, serverName: server.name))
            }
        }
        .sheet(item: $presentedMetric) { metric in
            if let snapshot {
                MetricDetailSheet(metric: metric, snapshot: snapshot, language: language)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(server.name)
                .font(.largeTitle.bold())

            HStack(spacing: 12) {
                Label("VEID \(server.veid)", systemImage: "number")

                if let snapshot {
                    Label(snapshot.location, systemImage: "mappin.and.ellipse")
                    Label(snapshot.status, systemImage: "dot.radiowaves.left.and.right")
                }
            }
            .foregroundStyle(.secondary)

            if let snapshot, !snapshot.ipAddresses.isEmpty {
                Label(snapshot.ipAddresses.joined(separator: ", "), systemImage: "network")
                    .foregroundStyle(.secondary)
            }

            if !server.note.isEmpty {
                Text(server.note)
                    .foregroundStyle(.secondary)
            }

            if let snapshot {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    Text(strings.lastUpdated(strings.relativeTimestamp(for: snapshot.updatedAt)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metrics(snapshot: ServerSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 16)], spacing: 16) {
            transferCard(for: snapshot)
            cpuCard(for: snapshot)
            memoryCard(for: snapshot)
            swapCard(for: snapshot)
            diskCard(for: snapshot)
        }
    }

    private func transferCard(for snapshot: ServerSnapshot) -> some View {
        let remaining = snapshot.monthlyTransferRemainingBytes.formatted(.byteCount(style: .file))
        let resetDate = snapshot.nextReset.formatted(date: .abbreviated, time: .omitted)
        let progress = snapshot.monthlyTransferTotalBytes > 0
            ? 1 - Double(snapshot.monthlyTransferRemainingBytes) / Double(snapshot.monthlyTransferTotalBytes)
            : 0.0

        return MetricCard(
            title: "Transfer Left",
            value: remaining,
            subtitle: "Resets \(resetDate)",
            progress: progress
        ) {
            presentedMetric = .transfer
        }
    }

    private func cpuCard(for snapshot: ServerSnapshot) -> some View {
        let value = "\(snapshot.cpuUsagePercent.formatted(.number.precision(.fractionLength(0))))%"

        return MetricCard(
            title: "CPU",
            value: value,
            subtitle: "Load \(snapshot.loadAverage)",
            progress: snapshot.cpuUsagePercent / 100
        ) {
            presentedMetric = .cpu
        }
    }

    private func memoryCard(for snapshot: ServerSnapshot) -> some View {
        let used = snapshot.memoryUsedBytes.formatted(.byteCount(style: .memory))
        let total = snapshot.memoryTotalBytes.formatted(.byteCount(style: .memory))

        return MetricCard(
            title: "Memory",
            value: used,
            subtitle: "of \(total)",
            progress: snapshot.memoryUsageFraction
        ) {
            presentedMetric = .memory
        }
    }

    private func swapCard(for snapshot: ServerSnapshot) -> some View {
        let used = snapshot.swapUsedBytes.formatted(.byteCount(style: .memory))
        let total = snapshot.swapTotalBytes.formatted(.byteCount(style: .memory))

        return MetricCard(
            title: "Swap",
            value: used,
            subtitle: "of \(total)",
            progress: snapshot.swapUsageFraction
        ) {
            presentedMetric = .swap
        }
    }

    private func diskCard(for snapshot: ServerSnapshot) -> some View {
        let used = snapshot.diskUsedBytes.formatted(.byteCount(style: .file))
        let total = snapshot.diskTotalBytes.formatted(.byteCount(style: .file))

        return MetricCard(
            title: "Disk",
            value: used,
            subtitle: "of \(total)",
            progress: snapshot.diskUsageFraction
        ) {
            presentedMetric = .disk
        }
    }

    private var actions: some View {
        GroupBox("Power Actions") {
            HStack(spacing: 12) {
                ForEach(PowerAction.allCases) { action in
                    powerActionButton(for: action)
                }
            }
        }
    }

    @ViewBuilder
    private func powerActionButton(for action: PowerAction) -> some View {
        let title = strings.powerActionTitle(action)

        if action == .stop {
            Button(title) {
                pendingPowerAction = action
            }
            .buttonStyle(.glass)
            .tint(.red)
        } else {
            Button(title) {
                pendingPowerAction = action
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let detailAction: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Button(action: detailAction) {
                        Image(systemName: "ellipsis")
                            .font(.caption.weight(.bold))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                }

                Text(value)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                ProgressView(value: progress)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MetricDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let metric: ServerMetricDetail
    let snapshot: ServerSnapshot
    let language: AppLanguage

    @AppStorage private var rangeUnitRaw: String
    @AppStorage private var rangeValue: Int

    init(metric: ServerMetricDetail, snapshot: ServerSnapshot, language: AppLanguage) {
        self.metric = metric
        self.snapshot = snapshot
        self.language = language
        _rangeUnitRaw = AppStorage(wrappedValue: HistoryRangeUnit.day.rawValue, "metric-detail-range-unit-\(metric.rawValue)")
        _rangeValue = AppStorage(wrappedValue: 7, "metric-detail-range-value-\(metric.rawValue)")
    }

    private var historyPoints: [MetricHistoryPoint] {
        switch metric {
        case .transfer:
            return snapshot.history
                .map { sample in
                    let total = sample.bandwidthTotalBytes > 0 ? sample.bandwidthTotalBytes : snapshot.monthlyTransferTotalBytes
                    let remaining = sample.bandwidthRemainingBytes > 0 || sample.bandwidthUsedBytes == 0
                        ? sample.bandwidthRemainingBytes
                        : max(0, total - sample.bandwidthUsedBytes)
                    return MetricHistoryPoint(timestamp: sample.timestamp, value: Double(remaining))
                }
        case .cpu:
            return snapshot.history
                .map { MetricHistoryPoint(timestamp: $0.timestamp, value: $0.cpuUsagePercent) }
        case .memory:
            return snapshot.history
                .filter { $0.memoryTotalBytes > 0 }
                .map { MetricHistoryPoint(timestamp: $0.timestamp, value: Double($0.memoryUsedBytes)) }
        case .swap:
            return snapshot.history
                .filter { $0.swapTotalBytes > 0 }
                .map { MetricHistoryPoint(timestamp: $0.timestamp, value: Double($0.swapUsedBytes)) }
        case .disk:
            return snapshot.history
                .filter { $0.diskTotalBytes > 0 }
                .map { MetricHistoryPoint(timestamp: $0.timestamp, value: Double($0.diskUsedBytes)) }
        }
    }

    private var strings: AppStrings {
        AppStrings(language: language)
    }

    private var rangeUnit: HistoryRangeUnit {
        get { HistoryRangeUnit(rawValue: rangeUnitRaw) ?? .day }
        nonmutating set { rangeUnitRaw = newValue.rawValue }
    }

    private var rangeValueBinding: Binding<Int> {
        Binding(
            get: { min(max(rangeValue, 1), rangeLimit) },
            set: { newValue in
                rangeValue = min(max(newValue, 1), rangeLimit)
            }
        )
    }

    private var visibleHistoryPoints: [MetricHistoryPoint] {
        historyPoints
            .filter { $0.timestamp >= lowerBoundDate && $0.value.isFinite && !$0.value.isNaN }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var renderedHistoryPoints: [MetricHistoryPoint] {
        if metric == .transfer {
            return aggregateTransferHistory(visibleHistoryPoints)
        }
        return downsample(visibleHistoryPoints, limit: 360)
    }

    private var lowerBoundDate: Date {
        let calendar = Calendar.current
        switch rangeUnit {
        case .hour:
            return calendar.date(byAdding: .hour, value: -rangeValue, to: .now) ?? .now
        case .day:
            return calendar.date(byAdding: .day, value: -rangeValue, to: .now) ?? .now
        case .month:
            return calendar.date(byAdding: .month, value: -rangeValue, to: .now) ?? .now
        }
    }

    private var yAxisDivisor: Double {
        switch metric {
        case .cpu:
            return 1
        case .transfer, .memory, .swap, .disk:
            return yAxisUnit.divisor
        }
    }

    private var yAxisUnit: ByteAxisUnit {
        let maxValue = visibleHistoryPoints.map(\.value).max() ?? historyPoints.map(\.value).max() ?? 0
        return ByteAxisUnit.bestFit(for: maxValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.title.bold())
                Spacer()
                Button(AppStrings(language: language).close) {
                    dismiss()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(primaryValue)
                    .font(.system(size: 28, weight: .semibold))
                Text(secondaryValue)
                    .foregroundStyle(.secondary)
                if let tertiaryValue {
                    Text(tertiaryValue)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            GroupBox(strings.metricHistory) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(strings.showLast)
                            .foregroundStyle(.secondary)

                        Stepper(value: rangeValueBinding, in: 1 ... rangeLimit) {
                            Text(min(max(rangeValue, 1), rangeLimit).formatted())
                                .monospacedDigit()
                        }
                        .frame(width: 120)

                        Picker(strings.rangeUnit, selection: Binding(
                            get: { rangeUnit },
                            set: { newValue in
                                rangeUnit = newValue
                                rangeValue = min(max(rangeValue, 1), rangeLimit)
                            }
                        )) {
                            ForEach(HistoryRangeUnit.allCases) { unit in
                                Text(title(for: unit)).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if renderedHistoryPoints.isEmpty {
                        Text(strings.noMetricHistory)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Chart(renderedHistoryPoints) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value(title, point.value / yAxisDivisor)
                            )
                            .foregroundStyle(Color.accentColor)
                            .interpolationMethod(.monotone)

                            if metric != .transfer {
                                AreaMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value(title, point.value / yAxisDivisor)
                                )
                                .foregroundStyle(Color.accentColor.opacity(0.12))
                                .interpolationMethod(.monotone)
                            }
                        }
                        .chartXScale(domain: lowerBoundDate ... .now)
                        .chartXAxis {
                            axisMarksForSelectedRange()
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let axisValue = value.as(Double.self) {
                                        Text(formatYAxisValue(axisValue))
                                    }
                                }
                            }
                        }
                        .frame(height: 260)
                    }
                }
            }
        }
        .padding(24)
    }

    private var rangeLimit: Int {
        switch rangeUnit {
        case .hour:
            return 168
        case .day:
            return 365
        case .month:
            return 24
        }
    }

    private func title(for unit: HistoryRangeUnit) -> String {
        switch unit {
        case .hour:
            return strings.hours
        case .day:
            return strings.days
        case .month:
            return strings.months
        }
    }

    @AxisContentBuilder
    private func axisMarksForSelectedRange() -> some AxisContent {
        switch rangeUnit {
        case .hour:
            AxisMarks(values: .stride(by: .hour, count: hourStride)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            }
        case .day:
            AxisMarks(values: .stride(by: .day, count: dayStride)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        case .month:
            AxisMarks(values: .stride(by: .month, count: monthStride)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.year().month(.abbreviated))
            }
        }
    }

    private var hourStride: Int {
        max(1, rangeValue / 6)
    }

    private var dayStride: Int {
        max(1, rangeValue / 6)
    }

    private var monthStride: Int {
        max(1, rangeValue / 6)
    }

    private func formatYAxisValue(_ value: Double) -> String {
        switch metric {
        case .cpu:
            return "\(value.formatted(.number.precision(.fractionLength(0))))%"
        case .transfer, .memory, .swap, .disk:
            return "\(value.formatted(.number.precision(.fractionLength(value >= 10 ? 0 : 1)))) \(yAxisUnit.label)"
        }
    }

    private func downsample(_ points: [MetricHistoryPoint], limit: Int) -> [MetricHistoryPoint] {
        guard points.count > limit, limit > 1 else {
            return points
        }

        let stride = Double(points.count - 1) / Double(limit - 1)
        var sampled: [MetricHistoryPoint] = []
        sampled.reserveCapacity(limit)

        for index in 0 ..< limit {
            let sourceIndex = Int((Double(index) * stride).rounded())
            sampled.append(points[min(sourceIndex, points.count - 1)])
        }

        return sampled
    }

    private func aggregateTransferHistory(_ points: [MetricHistoryPoint]) -> [MetricHistoryPoint] {
        guard !points.isEmpty else {
            return []
        }

        let calendar = Calendar.current
        var buckets: [Date: MetricHistoryPoint] = [:]

        for point in points {
            let key: Date
            switch rangeUnit {
            case .hour:
                let components = calendar.dateComponents([.year, .month, .day, .hour], from: point.timestamp)
                key = calendar.date(from: components) ?? point.timestamp
            case .day:
                let hour = calendar.component(.hour, from: point.timestamp)
                let bucketHour = (hour / 6) * 6
                var components = calendar.dateComponents([.year, .month, .day], from: point.timestamp)
                components.hour = bucketHour
                key = calendar.date(from: components) ?? point.timestamp
            case .month:
                let components = calendar.dateComponents([.year, .month, .day], from: point.timestamp)
                key = calendar.date(from: components) ?? point.timestamp
            }

            if let existing = buckets[key] {
                if point.timestamp > existing.timestamp {
                    buckets[key] = point
                }
            } else {
                buckets[key] = point
            }
        }

        return buckets.values.sorted { $0.timestamp < $1.timestamp }
    }

    private var title: String {
        switch metric {
        case .transfer:
            return "Transfer Left"
        case .cpu:
            return "CPU"
        case .memory:
            return "Memory"
        case .swap:
            return "Swap"
        case .disk:
            return "Disk"
        }
    }

    private var primaryValue: String {
        switch metric {
        case .transfer:
            return snapshot.monthlyTransferRemainingBytes.formatted(.byteCount(style: .file))
        case .cpu:
            return "\(snapshot.cpuUsagePercent.formatted(.number.precision(.fractionLength(0))))%"
        case .memory:
            return snapshot.memoryUsedBytes.formatted(.byteCount(style: .memory))
        case .swap:
            return snapshot.swapUsedBytes.formatted(.byteCount(style: .memory))
        case .disk:
            return snapshot.diskUsedBytes.formatted(.byteCount(style: .file))
        }
    }

    private var secondaryValue: String {
        switch metric {
        case .transfer:
            return "Current cycle total \(snapshot.monthlyTransferTotalBytes.formatted(.byteCount(style: .file)))"
        case .cpu:
            return "Load average \(snapshot.loadAverage)"
        case .memory:
            return "Total \(snapshot.memoryTotalBytes.formatted(.byteCount(style: .memory)))"
        case .swap:
            return "Total \(snapshot.swapTotalBytes.formatted(.byteCount(style: .memory)))"
        case .disk:
            return "Total \(snapshot.diskTotalBytes.formatted(.byteCount(style: .file)))"
        }
    }

    private var tertiaryValue: String? {
        switch metric {
        case .transfer:
            return "Used \(snapshot.monthlyTransferUsedBytes.formatted(.byteCount(style: .file))) • Reset \(snapshot.nextReset.formatted(date: .abbreviated, time: .omitted))"
        case .cpu:
            return nil
        case .memory:
            return utilizationText(used: snapshot.memoryUsedBytes, total: snapshot.memoryTotalBytes)
        case .swap:
            return utilizationText(used: snapshot.swapUsedBytes, total: snapshot.swapTotalBytes)
        case .disk:
            return utilizationText(used: snapshot.diskUsedBytes, total: snapshot.diskTotalBytes)
        }
    }

    private func utilizationText(used: Int64, total: Int64) -> String {
        guard total > 0 else { return "No total available" }
        let percent = (Double(used) / Double(total)) * 100
        return "Usage \(percent.formatted(.number.precision(.fractionLength(1))))%"
    }
}

private enum ByteAxisUnit {
    case megabytes
    case gigabytes
    case terabytes

    var divisor: Double {
        switch self {
        case .megabytes:
            return 1_048_576
        case .gigabytes:
            return 1_073_741_824
        case .terabytes:
            return 1_099_511_627_776
        }
    }

    var label: String {
        switch self {
        case .megabytes:
            return "MB"
        case .gigabytes:
            return "GB"
        case .terabytes:
            return "TB"
        }
    }

    static func bestFit(for value: Double) -> ByteAxisUnit {
        if value >= ByteAxisUnit.terabytes.divisor {
            return .terabytes
        }
        if value >= ByteAxisUnit.gigabytes.divisor {
            return .gigabytes
        }
        return .megabytes
    }
}
