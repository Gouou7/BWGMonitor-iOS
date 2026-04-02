import BWGMonitorShared
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var serverPendingDeletion: ServerRecord?

    private var strings: AppStrings {
        AppStrings(language: model.appLanguage)
    }

    private var versionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var buildString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "dev.govo.bwgmonitor.ios"
    }

    private var liveSettingsState: LiveSettingsState {
        LiveSettingsState(
            language: model.appLanguage,
            historyRetentionDays: model.historyRetentionDays,
            autoRefreshIntervalMinutes: model.autoRefreshIntervalMinutes
        )
    }

    var body: some View {
        Form {
            Section {
                Text(strings.settingsIntro)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(strings.displayLanguage, selection: $model.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(strings.languageName(language)).tag(language)
                    }
                }
            } header: {
                Text(strings.languageSection)
            } footer: {
                Text(strings.languageDescription)
            }

            Section {
                Stepper(value: $model.historyRetentionDays, in: 1 ... 3650) {
                    Text(strings.historyRetention(model.historyRetentionDays))
                }

                Stepper(value: $model.autoRefreshIntervalMinutes, in: 0 ... 240) {
                    Text(strings.automaticRefresh(model.autoRefreshIntervalMinutes))
                }

                Button(strings.clearCachedSnapshots) {
                    model.clearCachedSnapshots()
                }
                .buttonStyle(.glass)
            } header: {
                Text(strings.storageSection)
            } footer: {
                Text(strings.storageHint)
            }

            Section {
                if model.servers.isEmpty {
                    Text(strings.noServersConfigured)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.servers) { server in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.name)

                                Text("VEID \(server.veid)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if !server.note.isEmpty {
                                    Text(server.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button(strings.removeServer, role: .destructive) {
                                serverPendingDeletion = server
                            }
                        }
                    }
                }
            } header: {
                Text(strings.configuredServersSection)
            } footer: {
                Text(strings.configuredServersDescription)
            }

            Section {
                LabeledContent(strings.appName, value: strings.version(versionString, build: buildString))
                LabeledContent(strings.bundleIdentifier, value: bundleIdentifier)
            } header: {
                Text(strings.versionSection)
            } footer: {
                Text(model.lastRefreshMessage.isEmpty ? strings.noStatusMessage : model.lastRefreshMessage)
            }
        }
        .navigationTitle(strings.settings)
        .onChange(of: liveSettingsState) { _, _ in
            Task {
                await model.saveSettings()
            }
        }
        .confirmationDialog(strings.deleteThisServer, isPresented: Binding(
            get: { serverPendingDeletion != nil },
            set: { if !$0 { serverPendingDeletion = nil } }
        ), titleVisibility: .visible) {
            if let serverPendingDeletion {
                Button(strings.deleteServer, role: .destructive) {
                    Task {
                        await model.deleteServer(serverPendingDeletion)
                    }
                    self.serverPendingDeletion = nil
                }
            }

            Button(strings.cancel, role: .cancel) {
                serverPendingDeletion = nil
            }
        } message: {
            Text(strings.deleteServerWarning)
        }
    }
}

private struct LiveSettingsState: Equatable {
    let language: AppLanguage
    let historyRetentionDays: Int
    let autoRefreshIntervalMinutes: Int
}
