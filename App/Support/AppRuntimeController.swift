import BWGMonitorShared
import Foundation

enum AppRuntimeController {
    static func loadStoredSettings() -> AppSettings {
        let url = AppSupportPaths.settingsFileURL
        guard let data = try? Data(contentsOf: url) else {
            return AppSettings()
        }

        return (try? JSONDecoder.appSupport.decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    @discardableResult
    static func applyDockIconVisibility(hidden: Bool) -> Bool {
        false
    }

    static func applyStartupPresentation(using settings: AppSettings) {}

    static func synchronizeLaunchAtLogin(using settings: AppSettings) throws {}

    static func launchAtLoginEnabled() -> Bool {
        false
    }

    static func setLaunchAtLogin(_ enabled: Bool) throws {}
}
