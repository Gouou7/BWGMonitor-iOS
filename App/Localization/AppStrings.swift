import BWGMonitorShared
import Foundation

struct AppStrings {
    let language: AppLanguage

    private var resolvedLanguage: AppLanguage {
        guard language == .system else { return language }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("zh") ? .simplifiedChinese : .english
    }

    private var isChinese: Bool {
        resolvedLanguage == .simplifiedChinese
    }

    func text(_ english: String, _ chinese: String) -> String {
        isChinese ? chinese : english
    }

    var appName: String { "BWG Monitor" }
    var servers: String { text("Servers", "服务器") }
    var settings: String { text("Settings", "设置") }
    var addServer: String { text("Add Server", "添加服务器") }
    var refresh: String { text("Refresh", "刷新") }
    var refreshing: String { text("Refreshing", "刷新中") }
    var unfetched: String { text("Unfetched", "未获取") }
    var noServerSelected: String { text("No Server Selected", "未选择服务器") }
    var noServerConfiguredYet: String { text("No Servers Yet", "尚未配置服务器") }
    var noServerConfiguredDescription: String { text("Use the add button to create a server with a name, VEID, API key, and an optional note.", "使用添加按钮创建服务器，需要填写名称、VEID、API key，以及可选备注。") }
    var noServersConfigured: String { text("No servers configured", "未配置服务器") }
    var refreshKiwiVMData: String { text("Refresh KiwiVM Data", "刷新 KiwiVM 数据") }
    var clearRuntimeData: String { text("Clear Cached Data", "清除缓存数据") }
    var quitApp: String { text("Quit BWG Monitor", "退出 BWG Monitor") }
    var openMainWindow: String { text("Open Main Window", "打开主窗口") }
    var newServer: String { text("New Server", "新建服务器") }
    var editServer: String { text("Edit Server", "编辑服务器") }
    var name: String { text("Name", "名称") }
    var veid: String { text("VEID", "VEID") }
    var apiKey: String { text("API key", "API key") }
    var noteOptional: String { text("Note (optional)", "备注（可选）") }
    var cancel: String { text("Cancel", "取消") }
    var close: String { text("Close", "关闭") }
    var saveAndRefresh: String { text("Save And Refresh", "保存并刷新") }
    var saveChanges: String { text("Save Changes", "保存修改") }
    var deleteServer: String { text("Delete Server", "删除服务器") }
    var deleteThisServer: String { text("Delete this server?", "删除这台服务器？") }
    var removeServer: String { text("Remove", "移除") }
    var edit: String { text("Edit", "编辑") }
    var note: String { text("Note", "备注") }
    var lastUpdated: String { text("Last updated", "上次数据更新时间") }
    var confirmAction: String { text("Confirm Action", "确认操作") }

    var settingsIntro: String { text("Adjust language, refresh cadence, storage cleanup, and server management here.", "在这里调整语言、刷新频率、存储清理和服务器管理选项。") }
    var languageSection: String { text("Language", "语言") }
    var languageDescription: String { text("Choose the display language used by the app interface.", "选择应用界面使用的显示语言。") }
    var displayLanguage: String { text("Display language", "显示语言") }
    var storageSection: String { text("Storage", "存储") }
    var storageDescription: String { text("Control history retention, refresh cadence, and local cache cleanup.", "管理历史保留时间、自动刷新频率，以及本地缓存清理。") }
    var storageHint: String { text("History is retained per server. Clearing cached data only removes the latest local snapshots and does not delete saved server credentials.", "历史数据按服务器分别保留。清除缓存数据只会移除本地最新快照，不会删除已保存的服务器凭据。") }
    var menuBarSection: String { text("Menu Bar", "菜单栏") }
    var menuBarDescription: String { text("Choose how the app starts and which servers appear directly in the menu bar panel.", "设置应用启动方式，以及菜单栏面板中直接显示哪些服务器。") }
    var launchAtLogin: String { text("Launch at login", "登录时自动启动") }
    var launchToMenuBarOnly: String { text("Launch to menu bar only", "启动后仅显示菜单栏") }
    var hideDockIcon: String { text("Hide Dock icon", "隐藏 Dock 图标") }
    var startupVisibilityDescription: String { text("These options control startup behavior and Dock visibility.", "这些选项用于控制启动行为和 Dock 图标显示。") }
    var startupBehaviorTitle: String { text("Startup Behavior", "启动方式") }
    var menuBarContentTitle: String { text("Menu Bar Content", "菜单栏内容") }
    var menuBarShowAllServers: String { text("Show all configured servers", "显示所有已配置服务器") }
    var showInMenuBar: String { text("Show in menu bar", "在菜单栏中显示") }
    var noServersSelectedForMenuBar: String { text("No servers selected for the menu bar.", "菜单栏中未选择任何服务器。") }
    var transferLeft: String { text("Transfer Left", "剩余流量") }
    var cpu: String { text("CPU", "CPU") }
    var memory: String { text("Memory", "内存") }
    var swap: String { text("Swap", "Swap") }
    var disk: String { text("Disk", "磁盘") }
    var location: String { text("Location", "位置") }
    var openServer: String { text("Open Server", "打开服务器") }
    var configuredServersSection: String { text("Configured Servers", "已配置的服务器") }
    var configuredServersDescription: String { text("Review configured servers and remove entries you no longer need.", "查看当前已配置的服务器，并移除不再需要的条目。") }
    var versionSection: String { text("Version & About", "版本与关于") }
    var versionDescription: String { text("Basic build information for this local app bundle.", "当前本地应用包的基础版本信息。") }
    var saveSettings: String { text("Save Settings", "保存设置") }
    var clearCachedSnapshots: String { text("Clear Cached Snapshots", "清除缓存快照") }
    var metricHistory: String { text("History", "历史") }
    var noMetricHistory: String { text("No persisted history for this metric yet.", "这个指标还没有已保存的历史数据。") }
    var showLast: String { text("Show last", "显示最近") }
    var rangeUnit: String { text("Range Unit", "范围单位") }
    var hours: String { text("Hours", "小时") }
    var days: String { text("Days", "天") }
    var months: String { text("Months", "月") }

    var lastRefreshStatus: String { text("Last updated", "上次更新") }
    var noRefreshYet: String { text("No refresh yet", "尚未刷新") }

    func historyRetention(_ days: Int) -> String {
        text("History retention: \(days) day(s)", "历史保留时间：\(days) 天")
    }

    func automaticRefresh(_ minutes: Int) -> String {
        if minutes == 0 {
            return text("Automatic refresh: Off", "自动刷新：关闭")
        }

        return text("Automatic refresh: every \(minutes) minute(s)", "自动刷新：每 \(minutes) 分钟")
    }

    func savedSettingsSummary(retentionDays: Int, refreshMinutes: Int, launchAtLogin: Bool, launchToMenuBarOnly: Bool, hideDockIcon: Bool) -> String {
        let refreshSummary = refreshMinutes == 0
            ? text("manual refresh only", "仅手动刷新")
            : text("auto refresh every \(refreshMinutes) minute(s)", "每 \(refreshMinutes) 分钟自动刷新")
        let loginSummary = launchAtLogin ? text("launch at login on", "登录启动开启") : text("launch at login off", "登录启动关闭")
        let menuBarOnlySummary = launchToMenuBarOnly ? text("menu bar launch on", "仅菜单栏启动开启") : text("menu bar launch off", "仅菜单栏启动关闭")
        let dockSummary = hideDockIcon ? text("Dock hidden", "Dock 已隐藏") : text("Dock shown", "Dock 已显示")
        return text(
            "Saved settings: retention \(retentionDays) day(s), \(refreshSummary), \(loginSummary), \(menuBarOnlySummary), \(dockSummary).",
            "已保存设置：历史保留 \(retentionDays) 天，\(refreshSummary)，\(loginSummary)，\(menuBarOnlySummary)，\(dockSummary)。"
        )
    }

    func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .system:
            return text("System", "跟随系统")
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    func serverCount(_ count: Int) -> String {
        text("\(count) server(s)", "\(count) 台服务器")
    }

    func version(_ version: String, build: String) -> String {
        text("Version \(version) (\(build))", "版本 \(version)（\(build)）")
    }

    var bundleIdentifier: String { text("Bundle Identifier", "Bundle Identifier") }
    var appSupportLocation: String { text("App Support Location", "App Support 目录") }
    var noStatusMessage: String { text("No status yet.", "暂无状态信息。") }
    var deleteServerWarning: String { text("This removes the server, its local history database, and its saved API key.", "这会删除该服务器、本地历史数据库，以及它已保存的 API key。") }

    func addedServer(_ name: String) -> String {
        text("Added server \(name). Refreshing KiwiVM data.", "已添加服务器 \(name)，正在刷新 KiwiVM 数据。")
    }

    func updatedServer(_ name: String) -> String {
        text("Updated server \(name).", "已更新服务器 \(name)。")
    }

    func deletedServer(_ name: String) -> String {
        text("Deleted server \(name).", "已删除服务器 \(name)。")
    }

    var nameVeidAndApiKeyRequired: String {
        text("Name, VEID, and API key are required.", "名称、VEID 和 API key 为必填项。")
    }

    var nameRequired: String {
        text("Name and API key are required.", "名称和 API key 为必填项。")
    }

    var locale: Locale {
        switch language {
        case .system:
            return .current
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }

    func powerActionTitle(_ action: PowerAction) -> String {
        switch action {
        case .start:
            return text("Start", "开机")
        case .restart:
            return text("Restart", "重启")
        case .stop:
            return text("Stop", "关机")
        }
    }

    func confirmPowerActionTitle(_ action: PowerAction) -> String {
        switch action {
        case .start:
            return text("Start this server?", "确认开机这台服务器？")
        case .restart:
            return text("Restart this server?", "确认重启这台服务器？")
        case .stop:
            return text("Stop this server?", "确认关闭这台服务器？")
        }
    }

    func confirmPowerActionMessage(_ action: PowerAction, serverName: String) -> String {
        switch action {
        case .start:
            return text("A start request will be sent to \(serverName).", "将向 \(serverName) 发送开机请求。")
        case .restart:
            return text("A restart request will be sent to \(serverName).", "将向 \(serverName) 发送重启请求。")
        case .stop:
            return text("A stop request will be sent to \(serverName).", "将向 \(serverName) 发送关机请求。")
        }
    }

    func lastUpdated(_ relative: String) -> String {
        text("Last updated: \(relative)", "上次数据更新时间：\(relative)")
    }

    func lastRefresh(_ relative: String) -> String {
        text("Last updated: \(relative)", "上次更新：\(relative)")
    }

    func relativeTimestamp(for date: Date, reference now: Date = .now) -> String {
        let clampedDate = min(date, now)
        let elapsedSeconds = max(0, Int(now.timeIntervalSince(clampedDate)))

        if elapsedSeconds < 60 {
            return text("0 minutes ago", "0分钟前")
        }

        let minutes = elapsedSeconds / 60
        if minutes < 60 {
            return localizedRelative(value: minutes, englishUnit: "minute", chineseUnit: "分钟")
        }

        let hours = elapsedSeconds / 3_600
        if hours < 24 {
            return localizedRelative(value: hours, englishUnit: "hour", chineseUnit: "小时")
        }

        let days = elapsedSeconds / 86_400
        if days < 30 {
            return localizedRelative(value: days, englishUnit: "day", chineseUnit: "天")
        }

        let months = max(1, days / 30)
        return localizedRelative(value: months, englishUnit: "month", chineseUnit: "个月")
    }

    private func localizedRelative(value: Int, englishUnit: String, chineseUnit: String) -> String {
        let englishSuffix = value == 1 ? englishUnit : "\(englishUnit)s"
        return text("\(value) \(englishSuffix) ago", "\(value)\(chineseUnit)前")
    }
}
