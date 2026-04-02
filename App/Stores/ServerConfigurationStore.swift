import BWGMonitorShared
import Foundation

actor ServerConfigurationStore {
    func load() -> ServerConfiguration {
        let url = AppSupportPaths.serverConfigurationFileURL
        guard let data = try? Data(contentsOf: url) else {
            return ServerConfiguration()
        }

        do {
            return try JSONDecoder.appSupport.decode(ServerConfiguration.self, from: data)
        } catch {
            return ServerConfiguration()
        }
    }

    func save(_ configuration: ServerConfiguration) {
        do {
            let data = try JSONEncoder.pretty.encode(configuration)
            try data.write(to: AppSupportPaths.serverConfigurationFileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save server configuration: \(error)")
        }
    }
}
