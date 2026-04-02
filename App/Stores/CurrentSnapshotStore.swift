import BWGMonitorShared
import Foundation

actor CurrentSnapshotStore {
    func load() -> [ServerSnapshot] {
        let url = AppSupportPaths.currentSnapshotsFileURL
        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        do {
            return try JSONDecoder.appSupport.decode([ServerSnapshot].self, from: data)
        } catch {
            return []
        }
    }

    @discardableResult
    func save(_ snapshots: [ServerSnapshot]) -> Bool {
        do {
            let strippedSnapshots = snapshots.map(\.withoutHistory)
            let data = try JSONEncoder.pretty.encode(strippedSnapshots)
            try data.write(to: AppSupportPaths.currentSnapshotsFileURL, options: .atomic)
            return true
        } catch {
            assertionFailure("Failed to save current snapshots: \(error)")
            return false
        }
    }
}
