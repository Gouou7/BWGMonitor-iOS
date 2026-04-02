import BWGMonitorShared
import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel
    @State private var serverPendingDeletion: ServerRecord?

    private var strings: AppStrings {
        AppStrings(language: model.appLanguage)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.91, green: 0.95, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            NavigationStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ServerOverviewCard(model: model, strings: strings)

                        Text(strings.servers)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if model.servers.isEmpty {
                            ContentUnavailableView(
                                strings.noServerConfiguredYet,
                                systemImage: "server.rack",
                                description: Text(strings.noServerConfiguredDescription)
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 36)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(.white.opacity(0.28))
                            }
                        } else {
                            ForEach(model.servers) { server in
                                ServerRowCard(
                                    server: server,
                                    snapshot: model.snapshot(for: server.id),
                                    language: model.appLanguage,
                                    editAction: {
                                        model.presentEditServer(server)
                                    },
                                    deleteAction: {
                                        serverPendingDeletion = server
                                    }
                                ) {
                                    ServerDetailView(
                                        server: server,
                                        snapshot: model.snapshot(for: server.id),
                                        language: model.appLanguage
                                    ) { action in
                                        Task {
                                            await model.perform(action, on: server)
                                        }
                                    } clearHistoryHandler: {
                                        Task {
                                            await model.clearHistory(for: server)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(Color.clear)
                .navigationTitle(strings.servers)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView(model: model)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3.weight(.semibold))
                                .frame(width: 36, height: 36)
                        }
                        .accessibilityLabel(strings.settings)
                    }
                }
                .refreshable {
                    await model.refreshAll()
                }
            }
        }
        .sheet(item: $model.presentedSheet) { sheet in
            switch sheet {
            case .addServer:
                AddServerSheet(model: model)
            case .editServer:
                EditServerSheet(model: model)
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

private struct ServerOverviewCard: View {
    @Bindable var model: AppModel
    let strings: AppStrings

    private var refreshSummary: String {
        guard let lastDataRefreshDate = model.lastDataRefreshDate else {
            return strings.lastRefresh(strings.noRefreshYet)
        }

        return strings.lastRefresh(strings.relativeTimestamp(for: lastDataRefreshDate))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(strings.appName)
                    .font(.title2.weight(.bold))

                Text(refreshSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(model.lastRefreshMessage.isEmpty ? strings.noStatusMessage : model.lastRefreshMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await model.refreshAll()
                    }
                } label: {
                    OverviewActionButtonLabel(
                        title: model.isRefreshing ? strings.refreshing : strings.refresh,
                        systemImage: "arrow.clockwise"
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.isRefreshing)

                Button {
                    model.presentAddServer()
                } label: {
                    OverviewActionButtonLabel(
                        title: strings.addServer,
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.3))
        }
    }
}

private struct ServerRowCard<Destination: View>: View {
    let server: ServerRecord
    let snapshot: ServerSnapshot?
    let language: AppLanguage
    let editAction: () -> Void
    let deleteAction: () -> Void
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(destination: destination) {
                ConfiguredServerRow(
                    server: server,
                    snapshot: snapshot,
                    language: language
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button(AppStrings(language: language).edit) {
                    editAction()
                }

                Button(AppStrings(language: language).deleteServer, role: .destructive) {
                    deleteAction()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.28))
        }
    }
}

private struct ConfiguredServerRow: View {
    let server: ServerRecord
    let snapshot: ServerSnapshot?
    let language: AppLanguage

    private var strings: AppStrings {
        AppStrings(language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.headline)

                    Text("VEID \(server.veid)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Spacer()

                if let snapshot {
                    Text(snapshot.status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor(for: snapshot.status))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                } else {
                    Text(strings.unfetched)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            if let snapshot {
                HStack(spacing: 12) {
                    MetricPill(title: strings.cpu, value: "\(Int(snapshot.cpuUsagePercent.rounded()))%")
                    MetricPill(title: strings.memory, value: snapshot.memoryUsedBytes.formatted(.byteCount(style: .memory)))
                    MetricPill(title: strings.transferLeft, value: snapshot.monthlyTransferRemainingBytes.formatted(.byteCount(style: .file)))
                }
            }

            if !server.note.isEmpty {
                Text(server.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusColor(for status: String) -> Color {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "running":
            return .green
        case "stopped":
            return .red
        case "offline":
            return .gray
        default:
            return .orange
        }
    }
}

private struct OverviewActionButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.28))
        }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel

    private var strings: AppStrings {
        AppStrings(language: model.appLanguage)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(strings.newServer) {
                    TextField(strings.name, text: $model.serverDraft.name)
                    TextField(strings.veid, text: $model.serverDraft.veid)
                    SecureField(strings.apiKey, text: $model.serverDraft.apiKey)
                    TextField(strings.noteOptional, text: $model.serverDraft.note, axis: .vertical)
                }
            }
            .navigationTitle(strings.addServer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(strings.cancel) {
                        model.dismissSheet()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(strings.saveAndRefresh) {
                        Task {
                            await model.addServer()
                        }
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}

private struct EditServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel

    private var strings: AppStrings {
        AppStrings(language: model.appLanguage)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(strings.editServer) {
                    TextField(strings.name, text: $model.serverMetadataDraft.name)
                    SecureField(strings.apiKey, text: $model.serverMetadataDraft.apiKey)
                    TextField(strings.noteOptional, text: $model.serverMetadataDraft.note, axis: .vertical)
                }
            }
            .navigationTitle(strings.editServer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(strings.cancel) {
                        model.dismissSheet()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(strings.saveChanges) {
                        Task {
                            await model.saveServerMetadata()
                        }
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}
