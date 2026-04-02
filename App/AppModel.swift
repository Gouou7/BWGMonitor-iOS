import BWGMonitorShared
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    struct ServerDraft {
        var name = ""
        var veid = ""
        var apiKey = ""
        var note = ""
    }

    struct ServerMetadataDraft {
        var serverID = ""
        var name = ""
        var apiKey = ""
        var note = ""
    }

    enum SidebarSelection: Hashable {
        case server(String)
    }

    enum PresentedSheet: Identifiable {
        case addServer
        case editServer(String)

        var id: String {
            switch self {
            case .addServer:
                return "addServer"
            case let .editServer(serverID):
                return "editServer-\(serverID)"
            }
        }
    }

    var servers: [ServerRecord] = []
    var snapshots: [ServerSnapshot] = []
    var selection: SidebarSelection?
    var lastRefreshMessage = "No KiwiVM servers configured yet."
    var isRefreshing = false
    var appLanguage = AppSettings().language
    var historyRetentionDays = AppSettings().historyRetentionDays
    var autoRefreshIntervalMinutes = AppSettings().autoRefreshIntervalMinutes
    var launchAtLogin = AppSettings().launchAtLogin
    var launchToMenuBarOnly = AppSettings().launchToMenuBarOnly
    var hideDockIcon = AppSettings().hideDockIcon
    var menuBarUsesCustomServers = AppSettings().menuBarUsesCustomServers
    var menuBarServerIDs = AppSettings().menuBarServerIDs
    var serverDraft = ServerDraft()
    var serverMetadataDraft = ServerMetadataDraft()
    var presentedSheet: PresentedSheet?

    @ObservationIgnored private let snapshotStore = CurrentSnapshotStore()
    @ObservationIgnored private let configurationStore = ServerConfigurationStore()
    @ObservationIgnored private let settingsStore = AppSettingsStore()
    @ObservationIgnored private let historyStore = ServerHistoryStore()
    @ObservationIgnored private let client = KiwiVMClient()
    @ObservationIgnored private var autoRefreshTask: Task<Void, Never>?

    init() {
        Task {
            await bootstrap()
        }
    }

    var selectedServer: ServerRecord? {
        guard case let .server(id) = selection else { return nil }
        return server(for: id)
    }

    var selectedSnapshot: ServerSnapshot? {
        guard case let .server(id) = selection else { return nil }
        return snapshot(for: id)
    }

    var menuBarServers: [ServerRecord] {
        let visibleIDs = Set(resolvedMenuBarServerIDs)
        return servers.filter { visibleIDs.contains($0.id) }
    }

    var menuBarSnapshots: [ServerSnapshot] {
        let visibleIDs = Set(resolvedMenuBarServerIDs)
        return snapshots.filter { visibleIDs.contains($0.id) }
    }

    var lastDataRefreshDate: Date? {
        snapshots.map(\.updatedAt).max()
    }

    func bootstrap() async {
        let configuration = await configurationStore.load()
        let settings = await settingsStore.load()
        let storedSnapshots = await snapshotStore.load()
        let hadLegacyGroups = !configuration.groups.isEmpty || configuration.servers.contains(where: { $0.groupID != nil })

        servers = configuration.servers
            .map {
                var copy = $0
                copy.groupID = nil
                return copy
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        appLanguage = settings.language
        historyRetentionDays = settings.historyRetentionDays
        autoRefreshIntervalMinutes = settings.autoRefreshIntervalMinutes
        try? AppRuntimeController.synchronizeLaunchAtLogin(using: settings)
        launchAtLogin = AppRuntimeController.launchAtLoginEnabled()
        launchToMenuBarOnly = settings.launchToMenuBarOnly
        hideDockIcon = settings.hideDockIcon
        menuBarUsesCustomServers = settings.menuBarUsesCustomServers
        menuBarServerIDs = settings.menuBarServerIDs.filter { id in
            servers.contains(where: { $0.id == id })
        }

        _ = AppRuntimeController.applyDockIconVisibility(hidden: hideDockIcon)

        if hadLegacyGroups {
            await persistConfiguration()
        }

        configureAutoRefresh()

        guard !servers.isEmpty else {
            snapshots = []
            selection = nil
            lastRefreshMessage = "No KiwiVM servers configured yet."
            _ = await snapshotStore.save(snapshots)
            return
        }

        let validServerIDs = Set(servers.map(\.id))
        let filteredSnapshots = storedSnapshots.filter { validServerIDs.contains($0.id) }

        if filteredSnapshots.isEmpty {
            snapshots = []
            _ = await snapshotStore.save(snapshots)
            await refreshAll()
            return
        }

        snapshots = await hydrateSnapshots(filteredSnapshots)
        selection = .server(filteredSnapshots.first?.id ?? servers.first?.id ?? "")
        lastRefreshMessage = "Loaded cached KiwiVM snapshots."
        _ = await snapshotStore.save(snapshots)
    }

    func presentAddServer() {
        serverDraft = ServerDraft()
        presentedSheet = .addServer
    }

    func presentEditServer(_ server: ServerRecord) {
        serverMetadataDraft = ServerMetadataDraft(
            serverID: server.id,
            name: server.name,
            apiKey: server.apiKey,
            note: server.note
        )
        presentedSheet = .editServer(server.id)
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func addServer() async {
        let trimmedName = serverDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVEID = serverDraft.veid.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = serverDraft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = serverDraft.note.trimmingCharacters(in: .whitespacesAndNewlines)

        let strings = AppStrings(language: appLanguage)

        guard !trimmedName.isEmpty, !trimmedVEID.isEmpty, !trimmedKey.isEmpty else {
            lastRefreshMessage = strings.nameVeidAndApiKeyRequired
            return
        }

        let serverID = UUID().uuidString
        let server = ServerRecord(
            id: serverID,
            groupID: nil,
            name: trimmedName,
            veid: trimmedVEID,
            apiKey: trimmedKey,
            note: trimmedNote
        )

        servers.append(server)
        servers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if !menuBarUsesCustomServers {
            syncMenuBarServerIDsWithServers()
        }
        await persistConfiguration()
        serverDraft = ServerDraft()
        presentedSheet = nil
        lastRefreshMessage = strings.addedServer(trimmedName)
        await refreshAll()
    }

    func saveServerMetadata() async {
        let strings = AppStrings(language: appLanguage)
        let trimmedName = serverMetadataDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = serverMetadataDraft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = serverMetadataDraft.note.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedKey.isEmpty else {
            lastRefreshMessage = strings.nameRequired
            return
        }

        guard let index = servers.firstIndex(where: { $0.id == serverMetadataDraft.serverID }) else {
            lastRefreshMessage = strings.noStatusMessage
            return
        }

        let serverID = servers[index].id
        servers[index].name = trimmedName
        servers[index].apiKey = trimmedKey
        servers[index].note = trimmedNote
        servers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if let snapshotIndex = snapshots.firstIndex(where: { $0.id == serverID }) {
            snapshots[snapshotIndex].displayName = trimmedName
            snapshots[snapshotIndex].note = trimmedNote
            snapshots.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }

        await persistConfiguration()
        _ = await snapshotStore.save(snapshots)
        presentedSheet = nil
        lastRefreshMessage = strings.updatedServer(trimmedName)
    }

    func clearCachedSnapshots() {
        snapshots = []
        selection = nil
        lastRefreshMessage = "Cleared cached snapshots."

        Task {
            _ = await snapshotStore.save(snapshots)
        }
    }

    func saveSettings() async {
        let normalized = min(max(historyRetentionDays, 1), 3650)
        let normalizedRefresh = min(max(autoRefreshIntervalMinutes, 0), 1_440)
        let strings = AppStrings(language: appLanguage)
        historyRetentionDays = normalized
        autoRefreshIntervalMinutes = normalizedRefresh

        do {
            try AppRuntimeController.setLaunchAtLogin(launchAtLogin)
        } catch {
            launchAtLogin = AppRuntimeController.launchAtLoginEnabled()
            lastRefreshMessage = error.localizedDescription
            return
        }

        _ = AppRuntimeController.applyDockIconVisibility(hidden: hideDockIcon)
        await settingsStore.save(
            AppSettings(
                language: appLanguage,
                historyRetentionDays: normalized,
                autoRefreshIntervalMinutes: normalizedRefresh,
                launchAtLogin: launchAtLogin,
                launchToMenuBarOnly: launchToMenuBarOnly,
                hideDockIcon: hideDockIcon,
                menuBarUsesCustomServers: menuBarUsesCustomServers,
                menuBarServerIDs: menuBarUsesCustomServers ? menuBarServerIDs.filter { id in servers.contains(where: { $0.id == id }) } : []
            )
        )
        await pruneHistory()
        configureAutoRefresh()
        lastRefreshMessage = strings.savedSettingsSummary(
            retentionDays: normalized,
            refreshMinutes: normalizedRefresh,
            launchAtLogin: launchAtLogin,
            launchToMenuBarOnly: launchToMenuBarOnly,
            hideDockIcon: hideDockIcon
        )
    }

    func refreshAll() async {
        guard !isRefreshing else {
            return
        }

        guard !servers.isEmpty else {
            snapshots = []
            selection = nil
            lastRefreshMessage = "No configured servers yet."
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        var freshSnapshots: [ServerSnapshot] = []
        var failures: [String] = []

        for server in servers {
            do {
                let credentials = KiwiVMClient.Credentials(veid: server.veid, apiKey: server.apiKey)

                let serviceInfo = try await client.getServiceInfo(credentials: credentials)
                let liveInfo = try? await client.getLiveServiceInfo(credentials: credentials)
                let rawStats = (try? await client.getRawUsageStats(credentials: credentials)) ?? .array([])
                let parsedHistory = KiwiVMUsageStatsParser.parse(rawStats)
                let provisionalSnapshot = KiwiVMSnapshotMapper.makeSnapshot(
                    server: server,
                    serviceInfo: serviceInfo,
                    liveInfo: liveInfo,
                    history: parsedHistory.isEmpty ? fallbackHistory(for: server.id) : parsedHistory
                )
                let currentSample = UsageSample(
                    timestamp: provisionalSnapshot.updatedAt,
                    cpuUsagePercent: provisionalSnapshot.cpuUsagePercent,
                    bandwidthUsedBytes: provisionalSnapshot.monthlyTransferUsedBytes,
                    bandwidthTotalBytes: provisionalSnapshot.monthlyTransferTotalBytes,
                    bandwidthRemainingBytes: provisionalSnapshot.monthlyTransferRemainingBytes,
                    memoryUsedBytes: provisionalSnapshot.memoryUsedBytes,
                    memoryTotalBytes: provisionalSnapshot.memoryTotalBytes,
                    swapUsedBytes: provisionalSnapshot.swapUsedBytes,
                    swapTotalBytes: provisionalSnapshot.swapTotalBytes,
                    diskUsedBytes: provisionalSnapshot.diskUsedBytes,
                    diskTotalBytes: provisionalSnapshot.diskTotalBytes
                )

                try await historyStore.upsertHistorySamples(for: server.id, samples: parsedHistory, retentionDays: historyRetentionDays)
                try await historyStore.upsertCurrentSample(for: server.id, sample: currentSample, retentionDays: historyRetentionDays)
                let persistedHistory = try await historyStore.loadHistory(for: server.id)

                let snapshot = KiwiVMSnapshotMapper.makeSnapshot(
                    server: server,
                    serviceInfo: serviceInfo,
                    liveInfo: liveInfo,
                    history: persistedHistory.isEmpty ? fallbackHistory(for: server.id) : persistedHistory
                )

                freshSnapshots.append(snapshot)
            } catch {
                failures.append("\(server.name): \(error.localizedDescription)")
            }
        }

        guard !freshSnapshots.isEmpty else {
            let validServerIDs = Set(servers.map(\.id))
            snapshots = snapshots.filter { validServerIDs.contains($0.id) }
            if snapshots.isEmpty {
                selection = nil
            }
            lastRefreshMessage = failures.isEmpty ? "No server data was returned." : failures.joined(separator: " | ")
            return
        }

        snapshots = freshSnapshots.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        _ = await snapshotStore.save(snapshots)

        if let selectedServer, snapshots.contains(where: { $0.id == selectedServer.id }) {
            selection = .server(selectedServer.id)
        } else {
            selection = .server(snapshots.first?.id ?? "")
        }

        lastRefreshMessage = failures.isEmpty
            ? "Updated \(freshSnapshots.count) KiwiVM server(s)."
            : "Updated \(freshSnapshots.count) server(s). Failures: \(failures.joined(separator: " | "))"
    }

    func perform(_ action: PowerAction, on server: ServerRecord) async {
        do {
            let credentials = KiwiVMClient.Credentials(veid: server.veid, apiKey: server.apiKey)

            switch action {
            case .start:
                try await client.start(credentials: credentials)
            case .restart:
                try await client.restart(credentials: credentials)
            case .stop:
                try await client.stop(credentials: credentials)
            }

            lastRefreshMessage = "\(action.title) requested for \(server.name). Refreshing status."
            await refreshAll()
        } catch {
            lastRefreshMessage = error.localizedDescription
        }
    }

    func clearHistory(for server: ServerRecord) async {
        do {
            try await historyStore.clearHistory(for: server.id)
            if let index = snapshots.firstIndex(where: { $0.id == server.id }) {
                snapshots[index].history = []
            }
            _ = await snapshotStore.save(snapshots)
            lastRefreshMessage = "Cleared history for \(server.name)."
        } catch {
            lastRefreshMessage = error.localizedDescription
        }
    }

    func deleteServer(_ server: ServerRecord) async {
        let strings = AppStrings(language: appLanguage)
        do {
            try await historyStore.deleteStorage(for: server.id)

            servers.removeAll { $0.id == server.id }
            snapshots.removeAll { $0.id == server.id }
            menuBarServerIDs.removeAll { $0 == server.id }
            await persistConfiguration()
            await saveCurrentSettings()
            _ = await snapshotStore.save(snapshots)

            if let first = servers.first {
                selection = .server(first.id)
            } else {
                selection = nil
            }

            lastRefreshMessage = strings.deletedServer(server.name)
        } catch {
            lastRefreshMessage = error.localizedDescription
        }
    }

    func server(for id: String) -> ServerRecord? {
        servers.first { $0.id == id }
    }

    func snapshot(for id: String) -> ServerSnapshot? {
        snapshots.first { $0.id == id }
    }

    func selectServer(_ id: String) {
        selection = .server(id)
    }

    func toggleMenuBarSelection(for serverID: String, isVisible: Bool) {
        if isVisible {
            if !menuBarServerIDs.contains(serverID) {
                menuBarServerIDs.append(serverID)
            }
        } else {
            menuBarServerIDs.removeAll { $0 == serverID }
        }
        menuBarServerIDs = menuBarServerIDs.filter { id in servers.contains(where: { $0.id == id }) }
    }

    func isServerVisibleInMenuBar(_ serverID: String) -> Bool {
        resolvedMenuBarServerIDs.contains(serverID)
    }

    private func persistConfiguration() async {
        await configurationStore.save(ServerConfiguration(groups: [], servers: servers))
    }

    private func saveCurrentSettings() async {
        await settingsStore.save(
            AppSettings(
                language: appLanguage,
                historyRetentionDays: historyRetentionDays,
                autoRefreshIntervalMinutes: autoRefreshIntervalMinutes,
                launchAtLogin: launchAtLogin,
                launchToMenuBarOnly: launchToMenuBarOnly,
                hideDockIcon: hideDockIcon,
                menuBarUsesCustomServers: menuBarUsesCustomServers,
                menuBarServerIDs: menuBarUsesCustomServers ? menuBarServerIDs.filter { id in servers.contains(where: { $0.id == id }) } : []
            )
        )
    }

    private func pruneHistory() async {
        let serverIDs = servers.map(\.id)
        for serverID in serverIDs {
            try? await historyStore.pruneHistory(for: serverID, retentionDays: historyRetentionDays)
        }
        snapshots = await hydrateSnapshots(snapshots)
        _ = await snapshotStore.save(snapshots)
    }

    private func hydrateSnapshots(_ source: [ServerSnapshot]) async -> [ServerSnapshot] {
        var hydrated: [ServerSnapshot] = []

        for snapshot in source {
            var copy = snapshot
            copy.history = (try? await historyStore.loadHistory(for: snapshot.id)) ?? snapshot.history
            copy.groupName = nil
            hydrated.append(copy)
        }

        return hydrated
    }

    private func fallbackHistory(for serverID: String) -> [UsageSample] {
        snapshots.first(where: { $0.id == serverID })?.history ?? []
    }

    private func configureAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil

        guard autoRefreshIntervalMinutes > 0 else {
            return
        }

        autoRefreshTask = Task { [weak self] in
            let clock = ContinuousClock()

            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: .seconds(Double(self?.autoRefreshIntervalMinutes ?? 0) * 60))
                } catch {
                    break
                }

                guard !Task.isCancelled, let self, !self.servers.isEmpty else {
                    continue
                }

                await self.refreshAll()
            }
        }
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    private var resolvedMenuBarServerIDs: [String] {
        if menuBarUsesCustomServers {
            return menuBarServerIDs.filter { id in servers.contains(where: { $0.id == id }) }
        }
        return servers.map(\.id)
    }

    private func syncMenuBarServerIDsWithServers() {
        menuBarServerIDs = servers.map(\.id)
    }
}

enum PowerAction: String, CaseIterable, Identifiable {
    case start
    case restart
    case stop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start:
            return "Start"
        case .restart:
            return "Restart"
        case .stop:
            return "Stop"
        }
    }
}
