import BWGMonitorShared
import Foundation

actor AppSettingsStore {
    func load() -> AppSettings {
        let url = AppSupportPaths.settingsFileURL
        guard let data = try? Data(contentsOf: url) else {
            return AppSettings()
        }

        do {
            return try JSONDecoder.appSupport.decode(AppSettings.self, from: data)
        } catch {
            return AppSettings()
        }
    }

    func save(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder.pretty.encode(settings)
            try data.write(to: AppSupportPaths.settingsFileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save settings: \(error)")
        }
    }
}
