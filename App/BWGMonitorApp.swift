import Observation
import SwiftUI

@main
struct BWGMonitorApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
