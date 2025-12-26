import MusicKit
import SafariServices
import SwiftUI

// MARK: - Providers Config List View

struct ProvidersConfigView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var providerConfigs: [MAProviderConfig] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddProvider = false
    @State private var selectedFilter: MAProviderType? = nil

    var filteredConfigs: [MAProviderConfig] {
        guard let filter = selectedFilter else {
            return providerConfigs.sorted { $0.displayName < $1.displayName }
        }
        return
            providerConfigs
            .filter { $0.type == filter }
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading providers...")
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadProviders() }
                    }
                }
            } else if providerConfigs.isEmpty {
                ContentUnavailableView {
                    Label("No Providers", systemImage: "puzzlepiece")
                } description: {
                    Text("Add a music or player provider to get started")
                } actions: {
                    Button("Add Provider") {
                        showAddProvider = true
                    }
                }
            } else {
                List {
                    // Filter Section
                    Section {
                        Picker("Filter", selection: $selectedFilter) {
                            Text("All").tag(nil as MAProviderType?)
                            ForEach(MAProviderType.allCases.filter { $0 != .unknown }, id: \.self) {
                                type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type as MAProviderType?)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // Providers List
                    Section {
                        ForEach(filteredConfigs) { config in
                            NavigationLink(destination: EditProviderView(providerConfig: config)) {
                                ProviderConfigRow(config: config)
                            }
                        }
                        .onDelete(perform: deleteProvider)
                    } header: {
                        Text(
                            "\(filteredConfigs.count) Provider\(filteredConfigs.count == 1 ? "" : "s")"
                        )
                    }
                }
            }
        }
        .navigationTitle("Providers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddProvider = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadProviders() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showAddProvider) {
            NavigationStack {
                AddProviderView()
                    .environmentObject(appModel)
            }
        }
        .refreshable {
            await loadProviders()
        }
        .task {
            await loadProviders()
        }
    }

    private func loadProviders() async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            providerConfigs = try await api.getProviderConfigs()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func deleteProvider(at offsets: IndexSet) {
        let configsToDelete = offsets.map { filteredConfigs[$0] }

        Task {
            guard let api = appModel.api else { return }
            for config in configsToDelete {
                do {
                    try await api.removeProviderConfig(instanceID: config.instanceID)
                    await MainActor.run {
                        providerConfigs.removeAll { $0.instanceID == config.instanceID }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage =
                            "Failed to remove \(config.displayName): \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

// MARK: - Provider Config Row

struct ProviderConfigRow: View {
    let config: MAProviderConfig

    var body: some View {
        HStack(spacing: 12) {
            // Provider Icon
            ProviderIconView(domain: config.domain, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(config.displayName)
                        .font(.headline)

                    if !config.enabled {
                        Text("Disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                HStack {
                    Label(config.type.displayName, systemImage: config.type.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let stage = config.manifest?.stage, stage != .stable {
                        Text(stage.displayName)
                            .font(.caption)
                            .foregroundStyle(stageColor(stage))
                    }
                }

                if config.hasError, let error = config.lastError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(config.enabled ? 1.0 : 0.6)
    }

    private func stageColor(_ stage: MAProviderStage) -> Color {
        switch stage {
        case .stable: return .green
        case .beta: return .blue
        case .alpha: return .orange
        case .experimental: return .purple
        case .unmaintained: return .gray
        case .deprecated: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Provider Icon View

struct ProviderIconView: View {
    let domain: String
    let size: CGFloat

    var body: some View {
        // Fallback to a generic icon based on domain
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(providerColor.opacity(0.15))

            Image(systemName: providerIcon)
                .font(.system(size: size * 0.5))
                .foregroundStyle(providerColor)
        }
        .frame(width: size, height: size)
    }

    private var providerIcon: String {
        switch domain.lowercased() {
        case "spotify": return "music.note"
        case "apple_music": return "applelogo"
        case "tidal": return "waveform"
        case "qobuz": return "hifispeaker"
        case "youtube_music", "ytmusic": return "play.rectangle"
        case "deezer": return "music.quarternote.3"
        case "soundcloud": return "cloud"
        case "plex": return "play.square.stack"
        case "jellyfin": return "server.rack"
        case "subsonic": return "antenna.radiowaves.left.and.right"
        case "filesystem_local", "filesystem_smb": return "folder"
        case "sonos": return "hifispeaker.2"
        case "chromecast": return "tv"
        case "airplay": return "airplayaudio"
        case "slimproto": return "speaker.wave.3"
        case "snapcast": return "speaker.wave.2"
        case "hass": return "house"
        case "fully_kiosk": return "tablet"
        case "bluesound": return "hifispeaker"
        case "dlna": return "network"
        default: return "puzzlepiece"
        }
    }

    private var providerColor: Color {
        switch domain.lowercased() {
        case "spotify": return .green
        case "apple_music": return .pink
        case "tidal": return .black
        case "qobuz": return .blue
        case "youtube_music", "ytmusic": return .red
        case "deezer": return .purple
        case "soundcloud": return .orange
        case "plex": return .yellow
        case "jellyfin": return .purple
        case "sonos": return .black
        case "chromecast": return .blue
        case "airplay": return .gray
        default: return .accentColor
        }
    }
}

// MARK: - Add Provider View

struct AddProviderView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var manifests: [MAProviderManifest] = []
    @State private var existingConfigs: [MAProviderConfig] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedType: MAProviderType? = nil
    @State private var selectedProvider: MAProviderManifest?

    private let popularProviders = [
        "spotify", "tidal", "qobuz", "apple_music",
        "filesystem_local", "filesystem_smb",
        "sonos", "chromecast", "airplay",
    ]

    var availableManifests: [MAProviderManifest] {
        manifests
            .filter { !$0.builtin && $0.type != .unknown }
            .filter { manifest in
                // Filter out non-multi-instance providers that are already configured
                manifest.multiInstance || !existingConfigs.contains { $0.domain == manifest.domain }
            }
    }

    var filteredManifests: [MAProviderManifest] {
        var result = availableManifests

        // Apply type filter
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort: popular first, then alphabetically
        return result.sorted { a, b in
            let aPopular = popularProviders.firstIndex(of: a.domain)
            let bPopular = popularProviders.firstIndex(of: b.domain)

            if let aIdx = aPopular, let bIdx = bPopular {
                return aIdx < bIdx
            } else if aPopular != nil {
                return true
            } else if bPopular != nil {
                return false
            } else {
                return a.name < b.name
            }
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading available providers...")
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadData() }
                    }
                }
            } else {
                List {
                    // Type Filter
                    Section {
                        Picker("Provider Type", selection: $selectedType) {
                            Text("All Types").tag(nil as MAProviderType?)
                            Text("Music").tag(MAProviderType.music as MAProviderType?)
                            Text("Player").tag(MAProviderType.player as MAProviderType?)
                            Text("Metadata").tag(MAProviderType.metadata as MAProviderType?)
                            Text("Plugin").tag(MAProviderType.plugin as MAProviderType?)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Providers List
                    if filteredManifests.isEmpty {
                        ContentUnavailableView.search
                    } else {
                        Section {
                            ForEach(filteredManifests) { manifest in
                                Button {
                                    selectedProvider = manifest
                                } label: {
                                    ProviderManifestRow(manifest: manifest)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("\(filteredManifests.count) Available")
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search providers")
            }
        }
        .navigationTitle("Add Provider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedProvider) { manifest in
            NavigationStack {
                ProviderSetupView(manifest: manifest)
                    .environmentObject(appModel)
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            print("DEBUG AddProviderView: Loading manifests and configs...")
            async let manifestsTask = api.getProviderManifests()
            async let configsTask = api.getProviderConfigs()

            let (loadedManifests, loadedConfigs) = try await (manifestsTask, configsTask)
            print(
                "DEBUG AddProviderView: Loaded \(loadedManifests.count) manifests, \(loadedConfigs.count) configs"
            )
            manifests = Array(loadedManifests.values)
            existingConfigs = loadedConfigs
            isLoading = false
        } catch let decodingError as DecodingError {
            let detailedError: String
            switch decodingError {
            case .keyNotFound(let key, let context):
                detailedError =
                    "Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .typeMismatch(let type, let context):
                detailedError =
                    "Type mismatch for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                detailedError =
                    "Value not found for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .dataCorrupted(let context):
                detailedError = "Data corrupted: \(context.debugDescription)"
            @unknown default:
                detailedError = decodingError.localizedDescription
            }
            print("DEBUG AddProviderView: Decoding error: \(detailedError)")
            errorMessage = detailedError
            isLoading = false
        } catch {
            print("DEBUG AddProviderView: Error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Provider Manifest Row

struct ProviderManifestRow: View {
    let manifest: MAProviderManifest

    var body: some View {
        HStack(spacing: 12) {
            ProviderIconView(domain: manifest.domain, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(manifest.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if manifest.stage != .stable {
                        Text(manifest.stage.displayName)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(stageColor(manifest.stage))
                            .clipShape(Capsule())
                    }
                }

                Text(manifest.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func stageColor(_ stage: MAProviderStage) -> Color {
        switch stage {
        case .stable: return .green
        case .beta: return .blue
        case .alpha: return .orange
        case .experimental: return .purple
        case .unmaintained: return .gray
        case .deprecated: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Provider Setup View

struct ProviderSetupView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let manifest: MAProviderManifest

    @State private var configEntries: [MAConfigEntry] = []
    @State private var values: [String: AnyCodable] = [:]
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var sessionID = UUID().uuidString
    @State private var authURL: URL?
    @State private var showAuthSheet = false
    @State private var showAppleMusicHelper = false
    @State private var appleMusicAuthStatus: MusicAuthorization.Status = .notDetermined

    // Check if this is the Apple Music provider
    private var isAppleMusicProvider: Bool {
        manifest.domain.lowercased() == "apple_music"
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading configuration...")
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadConfigEntries() }
                    }
                }
            } else {
                Form {
                    // Provider Info Header
                    Section {
                        HStack(spacing: 16) {
                            ProviderIconView(domain: manifest.domain, size: 60)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(manifest.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text(manifest.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Apple Music Helper Section (only for Apple Music provider)
                    if isAppleMusicProvider {
                        Section {
                            // MusicKit Authorization Status
                            HStack {
                                Label("Apple Music Access", systemImage: appleMusicStatusIcon)
                                Spacer()
                                Text(appleMusicStatusText)
                                    .foregroundStyle(appleMusicStatusColor)
                            }

                            if appleMusicAuthStatus != .authorized {
                                Button {
                                    Task { await requestAppleMusicAuth() }
                                } label: {
                                    Label("Authorize Apple Music", systemImage: "apple.logo")
                                }
                            } else {
                                Button {
                                    Task { await getAppleMusicToken() }
                                } label: {
                                    Label("Get Token from Device", systemImage: "key.fill")
                                }
                            }

                            Button {
                                showAppleMusicHelper = true
                            } label: {
                                Label("Apple Music Setup Help", systemImage: "questionmark.circle")
                            }
                        } header: {
                            Text("Quick Setup")
                        } footer: {
                            Text(
                                "You can try to get the token automatically from your device's Apple Music subscription, or follow the manual instructions."
                            )
                        }
                    }

                    // Config Entries
                    ConfigEntriesFormView(
                        entries: configEntries,
                        values: $values,
                        onAction: handleAction
                    )
                }
            }
        }
        .navigationTitle("Setup \(manifest.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveConfig() }
                }
                .disabled(isSaving || !canSave)
            }
        }
        .overlay {
            if isSaving {
                ProgressView("Saving...")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            if let url = authURL {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showAppleMusicHelper) {
            NavigationStack {
                AppleMusicSetupView { token in
                    // When token is obtained from helper, set it in our values
                    values["music_user_token"] = AnyCodable(token)
                    showAppleMusicHelper = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showAppleMusicHelper = false
                        }
                    }
                }
            }
        }
        .task {
            await loadConfigEntries()
            if isAppleMusicProvider {
                appleMusicAuthStatus = MusicAuthorization.currentStatus
            }
        }
    }

    // MARK: - Apple Music Helpers

    private var appleMusicStatusIcon: String {
        switch appleMusicAuthStatus {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .restricted: return "lock.fill"
        case .notDetermined: return "questionmark.circle"
        @unknown default: return "questionmark.circle"
        }
    }

    private var appleMusicStatusText: String {
        switch appleMusicAuthStatus {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }

    private var appleMusicStatusColor: Color {
        switch appleMusicAuthStatus {
        case .authorized: return .green
        case .denied: return .red
        case .restricted: return .orange
        case .notDetermined: return .secondary
        @unknown default: return .secondary
        }
    }

    private func requestAppleMusicAuth() async {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            appleMusicAuthStatus = status
        }
    }

    private func getAppleMusicToken() async {
        // Use the AppleMusicHelper to try to get the token
        let helper = await AppleMusicHelper.shared
        let result = await helper.getUserToken()

        await MainActor.run {
            switch result {
            case .success(let token):
                // Set the token in our values
                values["music_user_token"] = AnyCodable(token)
            case .failure(let error):
                // Show error and open helper
                errorMessage = error.localizedDescription
                showAppleMusicHelper = true
            }
        }
    }

    private var canSave: Bool {
        // Check all required fields have values
        for entry in configEntries {
            if entry.required && !entry.hidden {
                let value = values[entry.key]
                if value == nil || (value?.stringValue?.isEmpty ?? true) {
                    // Check if there's a default value
                    if entry.defaultValue == nil
                        || (entry.defaultValue?.stringValue?.isEmpty ?? true)
                    {
                        return false
                    }
                }
            }
        }
        return true
    }

    private func loadConfigEntries(action: String? = nil) async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            isLoading = false
            return
        }

        isLoading = action == nil  // Only show loading on initial load
        errorMessage = nil

        do {
            var currentValues = values
            currentValues["session_id"] = AnyCodable(sessionID)

            print("DEBUG: Loading config entries for provider: \(manifest.domain)")
            print("DEBUG: Action: \(action ?? "nil")")

            configEntries = try await api.getProviderConfigEntries(
                providerDomain: manifest.domain,
                instanceID: nil,
                action: action,
                values: action != nil ? currentValues : ["session_id": AnyCodable(sessionID)]
            )

            print("DEBUG: Loaded \(configEntries.count) config entries")

            // Initialize values from entries
            for entry in configEntries {
                if values[entry.key] == nil {
                    values[entry.key] = entry.value ?? entry.defaultValue
                }
            }

            isLoading = false
        } catch let decodingError as DecodingError {
            // Provide detailed error for decoding issues
            let detailedError: String
            switch decodingError {
            case .keyNotFound(let key, let context):
                detailedError =
                    "Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). Debug: \(context.debugDescription)"
            case .typeMismatch(let type, let context):
                detailedError =
                    "Type mismatch for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). Debug: \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                detailedError =
                    "Value not found for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). Debug: \(context.debugDescription)"
            case .dataCorrupted(let context):
                detailedError =
                    "Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). Debug: \(context.debugDescription)"
            @unknown default:
                detailedError = decodingError.localizedDescription
            }
            print("DEBUG: Config entries decoding error: \(detailedError)")
            errorMessage = detailedError
            isLoading = false
        } catch {
            print("DEBUG: Config entries error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleAction(_ action: String) {
        Task {
            await loadConfigEntries(action: action)
        }
    }

    private func saveConfig() async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            return
        }

        isSaving = true

        do {
            var saveValues = values
            saveValues["session_id"] = AnyCodable(sessionID)

            try await api.saveProviderConfigVoid(
                providerDomain: manifest.domain,
                values: saveValues,
                instanceID: nil
            )

            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch let decodingError as DecodingError {
            // Provide more detailed error for decoding issues
            let detailedError: String
            switch decodingError {
            case .keyNotFound(let key, let context):
                detailedError =
                    "Missing key '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .typeMismatch(let type, let context):
                detailedError =
                    "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                detailedError =
                    "Value not found for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .dataCorrupted(let context):
                detailedError = "Data corrupted: \(context.debugDescription)"
            @unknown default:
                detailedError = decodingError.localizedDescription
            }
            print("Provider save decoding error: \(detailedError)")
            await MainActor.run {
                isSaving = false
                errorMessage =
                    "Configuration saved but response parsing failed. Please refresh to verify."
            }
        } catch {
            print("Provider save error: \(error)")
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Edit Provider View

struct EditProviderView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let providerConfig: MAProviderConfig

    @State private var configEntries: [MAConfigEntry] = []
    @State private var values: [String: AnyCodable] = [:]
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading configuration...")
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadConfigEntries() }
                    }
                }
            } else {
                Form {
                    // Provider Info Header
                    Section {
                        HStack(spacing: 16) {
                            ProviderIconView(domain: providerConfig.domain, size: 60)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(providerConfig.displayName)
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                if let manifest = providerConfig.manifest {
                                    Text(manifest.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Error Alert
                    if providerConfig.hasError, let error = providerConfig.lastError {
                        Section {
                            Label {
                                Text(error)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        } header: {
                            Text("Provider Error")
                        }
                    }

                    // Config Entries
                    ConfigEntriesFormView(
                        entries: configEntries,
                        values: $values,
                        onAction: handleAction
                    )

                    // Actions Section
                    Section {
                        Button {
                            Task {
                                try? await appModel.api?.reloadProvider(
                                    instanceID: providerConfig.instanceID)
                            }
                        } label: {
                            Label("Reload Provider", systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Remove Provider", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Provider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveConfig() }
                }
                .disabled(isSaving)
            }
        }
        .overlay {
            if isSaving {
                ProgressView("Saving...")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .confirmationDialog(
            "Remove Provider",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task { await deleteProvider() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Are you sure you want to remove \(providerConfig.displayName)? This cannot be undone."
            )
        }
        .task {
            await loadConfigEntries()
        }
    }

    private func loadConfigEntries(action: String? = nil) async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            isLoading = false
            return
        }

        isLoading = action == nil
        errorMessage = nil

        do {
            configEntries = try await api.getProviderConfigEntries(
                providerDomain: providerConfig.domain,
                instanceID: providerConfig.instanceID,
                action: action,
                values: action != nil ? values : nil
            )

            // Initialize values from entries
            for entry in configEntries {
                if values[entry.key] == nil {
                    values[entry.key] = entry.value ?? entry.defaultValue
                }
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleAction(_ action: String) {
        Task {
            await loadConfigEntries(action: action)
        }
    }

    private func saveConfig() async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            return
        }

        isSaving = true

        do {
            try await api.saveProviderConfigVoid(
                providerDomain: providerConfig.domain,
                values: values,
                instanceID: providerConfig.instanceID
            )

            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteProvider() async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            return
        }

        do {
            try await api.removeProviderConfig(instanceID: providerConfig.instanceID)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Config Entries Form View

struct ConfigEntriesFormView: View {
    let entries: [MAConfigEntry]
    @Binding var values: [String: AnyCodable]
    var onAction: ((String) -> Void)?

    private var groupedEntries: [(String, [MAConfigEntry])] {
        let categories = Set(entries.map { $0.category })
        let sortedCategories =
            ["generic"] + categories.filter { $0 != "generic" && $0 != "advanced" }.sorted() + [
                "advanced"
            ]

        return sortedCategories.compactMap { category in
            let categoryEntries = entries.filter { $0.category == category && !$0.hidden }
            if categoryEntries.isEmpty { return nil }
            return (category, categoryEntries)
        }
    }

    var body: some View {
        ForEach(groupedEntries, id: \.0) { category, categoryEntries in
            Section {
                ForEach(categoryEntries) { entry in
                    ConfigEntryFieldView(
                        entry: entry,
                        value: binding(for: entry.key),
                        onAction: onAction
                    )
                }
            } header: {
                Text(categoryDisplayName(category))
            }
        }
    }

    private func binding(for key: String) -> Binding<AnyCodable?> {
        Binding(
            get: { values[key] },
            set: { values[key] = $0 }
        )
    }

    private func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "generic": return "General"
        case "advanced": return "Advanced"
        case "authentication": return "Authentication"
        case "audio": return "Audio"
        case "network": return "Network"
        case "playback": return "Playback"
        case "sync": return "Sync"
        default: return category.capitalized
        }
    }
}

// MARK: - Config Entry Field View

struct ConfigEntryFieldView: View {
    let entry: MAConfigEntry
    @Binding var value: AnyCodable?
    var onAction: ((String) -> Void)?

    var body: some View {
        switch entry.type {
        case .boolean:
            Toggle(entry.label, isOn: boolBinding)

        case .string:
            if let options = entry.options, !options.isEmpty {
                Picker(entry.label, selection: stringBinding) {
                    ForEach(options, id: \.value.stringValue) { option in
                        Text(option.title).tag(option.value.stringValue ?? "")
                    }
                }
            } else {
                TextField(entry.label, text: stringBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

        case .secureString:
            SecureField(entry.label, text: stringBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

        case .integer:
            if let range = entry.range, range.count >= 2 {
                VStack(alignment: .leading) {
                    Text(entry.label)
                    HStack {
                        Slider(
                            value: doubleBinding,
                            in: range[0]...range[1],
                            step: range.count > 2 ? range[2] : 1
                        )
                        Text("\(intBinding.wrappedValue)")
                            .monospacedDigit()
                            .frame(minWidth: 40)
                    }
                }
            } else if let options = entry.options, !options.isEmpty {
                Picker(entry.label, selection: intBinding) {
                    ForEach(options, id: \.value.intValue) { option in
                        Text(option.title).tag(option.value.intValue ?? 0)
                    }
                }
            } else {
                TextField(entry.label, value: intBinding, format: .number)
                    .keyboardType(.numberPad)
            }

        case .float:
            if let range = entry.range, range.count >= 2 {
                VStack(alignment: .leading) {
                    Text(entry.label)
                    HStack {
                        Slider(
                            value: doubleBinding,
                            in: range[0]...range[1],
                            step: range.count > 2 ? range[2] : 0.1
                        )
                        Text(String(format: "%.1f", doubleBinding.wrappedValue))
                            .monospacedDigit()
                            .frame(minWidth: 40)
                    }
                }
            } else {
                TextField(entry.label, value: doubleBinding, format: .number)
                    .keyboardType(.decimalPad)
            }

        case .label:
            Text(entry.label)
                .foregroundStyle(.secondary)

        case .divider:
            Divider()

        case .action:
            Button {
                onAction?(entry.action ?? entry.key)
            } label: {
                HStack {
                    Text(entry.actionLabel ?? entry.label)
                    Spacer()
                    Image(systemName: "arrow.right.circle")
                }
            }

        case .alert:
            Label {
                Text(entry.label)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

        case .icon, .unknown:
            EmptyView()
        }
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: { value?.boolValue ?? entry.defaultValue?.boolValue ?? false },
            set: { value = AnyCodable($0) }
        )
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { value?.stringValue ?? entry.defaultValue?.stringValue ?? "" },
            set: { value = AnyCodable($0) }
        )
    }

    private var intBinding: Binding<Int> {
        Binding(
            get: { value?.intValue ?? entry.defaultValue?.intValue ?? 0 },
            set: { value = AnyCodable($0) }
        )
    }

    private var doubleBinding: Binding<Double> {
        Binding(
            get: { value?.doubleValue ?? entry.defaultValue?.doubleValue ?? 0.0 },
            set: { value = AnyCodable($0) }
        )
    }
}

// MARK: - Safari View for OAuth

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ProvidersConfigView()
            .environmentObject(AppModel())
    }
}
