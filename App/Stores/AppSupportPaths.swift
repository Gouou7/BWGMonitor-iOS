import Foundation

enum AppSupportPaths {
    static let appName = "BWGMonitor"

    static var rootDirectoryURL: URL {
        directory(named: nil)
    }

    static var serverConfigurationFileURL: URL {
        rootDirectoryURL.appendingPathComponent("servers.json")
    }

    static var settingsFileURL: URL {
        rootDirectoryURL.appendingPathComponent("settings.json")
    }

    static var currentSnapshotsFileURL: URL {
        rootDirectoryURL.appendingPathComponent("current_snapshots.json")
    }

    static var serversDirectoryURL: URL {
        directory(named: "Servers")
    }

    static func serverDirectoryURL(serviceID: String) -> URL {
        let url = serversDirectoryURL.appendingPathComponent(serviceID, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func serverHistoryDatabaseURL(serviceID: String) -> URL {
        serverDirectoryURL(serviceID: serviceID).appendingPathComponent("history.sqlite")
    }

    @discardableResult
    private static func directory(named name: String?) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = base.appendingPathComponent(appName, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        guard let name else {
            return root
        }

        let child = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        return child
    }
}
