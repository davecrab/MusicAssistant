import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Library") {
                    ForEach(LibraryCategory.allCases) { category in
                        NavigationLink(destination: destinationView(for: category)) {
                            Label(category.displayName, systemImage: category.icon)
                        }
                    }
                }
            }
            .navigationTitle("Browse")
        }
    }

    @ViewBuilder
    private func destinationView(for category: LibraryCategory) -> some View {
        switch category {
        case .albums:
            AlbumsListView()
        case .artists:
            ArtistsListView()
        case .tracks:
            TracksListView()
        case .playlists:
            PlaylistsListView()
        case .audiobooks:
            AudiobooksListView()
        case .radio:
            RadioListView()
        }
    }
}

// MARK: - Albums List View

struct AlbumsListView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var albums: [MAAlbum] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMore = true
    private let pageSize = 50

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(albums) { album in
                    NavigationLink(destination: AlbumDetailView(album: album)) {
                        AlbumGridItem(album: album)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if album == albums.last && hasMore && !isLoading {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            .padding()

            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .navigationTitle("Albums")
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) {
            Task {
                offset = 0
                hasMore = true
                await loadAlbums(reset: true)
            }
        }
        .onChange(of: search) { _, newValue in
            if newValue.isEmpty {
                Task {
                    offset = 0
                    hasMore = true
                    await loadAlbums(reset: true)
                }
            }
        }
        .task { await loadAlbums(reset: true) }
        .refreshable { await loadAlbums(reset: true) }
    }

    private func loadAlbums(reset: Bool) async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        if reset {
            offset = 0
            hasMore = true
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await api.execute(
                command: "music/albums/library_items",
                args: [
                    "search": search.isEmpty ? .null : .string(search),
                    "limit": .int(pageSize),
                    "offset": .int(offset),
                ],
                as: [MAAlbum].self
            )
            if reset {
                albums = result
            } else {
                albums.append(contentsOf: result)
            }
            hasMore = result.count >= pageSize
            offset += result.count
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func loadMore() async {
        await loadAlbums(reset: false)
    }
}

struct AlbumGridItem: View {
    @EnvironmentObject private var appModel: AppModel
    let album: MAAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(urlString: album.artworkPath, baseURL: appModel.settings.serverURL)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(album.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Album Detail View

struct AlbumDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let album: MAAlbum
    @State private var tracks: [MATrack] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Album Header
                VStack(spacing: 12) {
                    ArtworkView(urlString: album.artworkPath, baseURL: appModel.settings.serverURL)
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    VStack(spacing: 4) {
                        Text(album.name)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text(album.artistName)
                            .font(.title3)
                            .foregroundStyle(.pink)

                        if let year = album.year {
                            Text(String(year))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 16) {
                        Button {
                            Task { await playAlbum(shuffle: false) }
                        } label: {
                            Label("Play", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)

                        Button {
                            Task { await playAlbum(shuffle: true) }
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .padding(.top)

                // Track List
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRow(track: track, index: index + 1) {
                                Task { await playTrack(track) }
                            }
                            if index < tracks.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTracks() }
    }

    private func loadTracks() async {
        guard let api = appModel.api, let itemID = album.itemID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            tracks = try await api.execute(
                command: "music/albums/album_tracks",
                args: [
                    "item_id": .string(itemID),
                    "provider_instance_id_or_domain": .string(album.provider ?? "library"),
                ],
                as: [MATrack].self
            )
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func playAlbum(shuffle: Bool) async {
        await appModel.playAlbum(album, shuffle: shuffle)
    }

    private func playTrack(_ track: MATrack) async {
        await appModel.playTrack(track)
    }
}

struct TrackRow: View {
    @EnvironmentObject private var appModel: AppModel
    let track: MATrack
    let index: Int?
    let onTap: () -> Void

    init(track: MATrack, index: Int? = nil, onTap: @escaping () -> Void) {
        self.track = track
        self.index = index
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let index {
                    Text("\(index)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                } else {
                    ArtworkView(urlString: track.artworkPath, baseURL: appModel.settings.serverURL)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text(track.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let duration = track.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Artists List View

struct ArtistsListView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var artists: [MAArtist] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMore = true
    private let pageSize = 50

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(artists) { artist in
                    NavigationLink(destination: ArtistDetailView(artist: artist)) {
                        ArtistGridItem(artist: artist)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if artist == artists.last && hasMore && !isLoading {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            .padding()

            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .navigationTitle("Artists")
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) {
            Task {
                offset = 0
                hasMore = true
                await loadArtists(reset: true)
            }
        }
        .onChange(of: search) { _, newValue in
            if newValue.isEmpty {
                Task {
                    offset = 0
                    hasMore = true
                    await loadArtists(reset: true)
                }
            }
        }
        .task { await loadArtists(reset: true) }
        .refreshable { await loadArtists(reset: true) }
    }

    private func loadArtists(reset: Bool) async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        if reset {
            offset = 0
            hasMore = true
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await api.execute(
                command: "music/artists/library_items",
                args: [
                    "search": search.isEmpty ? .null : .string(search),
                    "limit": .int(pageSize),
                    "offset": .int(offset),
                ],
                as: [MAArtist].self
            )
            if reset {
                artists = result
            } else {
                artists.append(contentsOf: result)
            }
            hasMore = result.count >= pageSize
            offset += result.count
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func loadMore() async {
        await loadArtists(reset: false)
    }
}

struct ArtistGridItem: View {
    @EnvironmentObject private var appModel: AppModel
    let artist: MAArtist

    var body: some View {
        VStack(spacing: 8) {
            ArtworkView(urlString: artist.artworkPath, baseURL: appModel.settings.serverURL)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            Text(artist.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Artist Detail View

struct ArtistDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let artist: MAArtist
    @State private var albums: [MAAlbum] = []
    @State private var tracks: [MATrack] = []
    @State private var isLoading = false

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Artist Header
                VStack(spacing: 12) {
                    ArtworkView(urlString: artist.artworkPath, baseURL: appModel.settings.serverURL)
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    Text(artist.name)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await playArtist() }
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                            .frame(width: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                }
                .padding(.top)

                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Albums Section
                    if !albums.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Albums")
                                .font(.title2.weight(.bold))
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(albums) { album in
                                    NavigationLink(destination: AlbumDetailView(album: album)) {
                                        AlbumGridItem(album: album)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Top Tracks Section
                    if !tracks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Tracks")
                                .font(.title2.weight(.bold))
                                .padding(.horizontal)

                            LazyVStack(spacing: 0) {
                                ForEach(
                                    Array(tracks.prefix(10).enumerated()), id: \.element.id
                                ) { index, track in
                                    TrackRow(track: track, index: index + 1) {
                                        Task { await playTrack(track) }
                                    }
                                    if index < min(tracks.count, 10) - 1 {
                                        Divider()
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadContent() }
    }

    private func loadContent() async {
        guard let api = appModel.api, let itemID = artist.itemID else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let albumsTask = api.execute(
                command: "music/artists/artist_albums",
                args: [
                    "item_id": .string(itemID),
                    "provider_instance_id_or_domain": .string(artist.provider ?? "library"),
                ],
                as: [MAAlbum].self
            )

            async let tracksTask = api.execute(
                command: "music/artists/artist_tracks",
                args: [
                    "item_id": .string(itemID),
                    "provider_instance_id_or_domain": .string(artist.provider ?? "library"),
                ],
                as: [MATrack].self
            )

            albums = try await albumsTask
            tracks = try await tracksTask
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func playArtist() async {
        guard let uri = artist.uri else { return }
        await appModel.playMedia(uri: uri)
    }

    private func playTrack(_ track: MATrack) async {
        await appModel.playTrack(track)
    }
}

// MARK: - Tracks List View

struct TracksListView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var tracks: [MATrack] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMore = true
    private let pageSize = 50

    var body: some View {
        List {
            ForEach(tracks) { track in
                TrackRow(track: track) {
                    Task { await playTrack(track) }
                }
                .onAppear {
                    if track == tracks.last && hasMore && !isLoading {
                        Task { await loadMore() }
                    }
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Tracks")
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) {
            Task {
                offset = 0
                hasMore = true
                await loadTracks(reset: true)
            }
        }
        .onChange(of: search) { _, newValue in
            if newValue.isEmpty {
                Task {
                    offset = 0
                    hasMore = true
                    await loadTracks(reset: true)
                }
            }
        }
        .task { await loadTracks(reset: true) }
        .refreshable { await loadTracks(reset: true) }
    }

    private func loadTracks(reset: Bool) async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        if reset {
            offset = 0
            hasMore = true
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await api.execute(
                command: "music/tracks/library_items",
                args: [
                    "search": search.isEmpty ? .null : .string(search),
                    "limit": .int(pageSize),
                    "offset": .int(offset),
                ],
                as: [MATrack].self
            )
            if reset {
                tracks = result
            } else {
                tracks.append(contentsOf: result)
            }
            hasMore = result.count >= pageSize
            offset += result.count
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func loadMore() async {
        await loadTracks(reset: false)
    }

    private func playTrack(_ track: MATrack) async {
        await appModel.playTrack(track)
    }
}

// MARK: - Playlists List View

struct PlaylistsListView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var playlists: [MAPlaylist] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMore = true
    private let pageSize = 50

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(playlists) { playlist in
                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                        PlaylistGridItem(playlist: playlist)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if playlist == playlists.last && hasMore && !isLoading {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            .padding()

            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .navigationTitle("Playlists")
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) {
            Task {
                offset = 0
                hasMore = true
                await loadPlaylists(reset: true)
            }
        }
        .onChange(of: search) { _, newValue in
            if newValue.isEmpty {
                Task {
                    offset = 0
                    hasMore = true
                    await loadPlaylists(reset: true)
                }
            }
        }
        .task { await loadPlaylists(reset: true) }
        .refreshable { await loadPlaylists(reset: true) }
    }

    private func loadPlaylists(reset: Bool) async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        if reset {
            offset = 0
            hasMore = true
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await api.execute(
                command: "music/playlists/library_items",
                args: [
                    "search": search.isEmpty ? .null : .string(search),
                    "limit": .int(pageSize),
                    "offset": .int(offset),
                ],
                as: [MAPlaylist].self
            )
            if reset {
                playlists = result
            } else {
                playlists.append(contentsOf: result)
            }
            hasMore = result.count >= pageSize
            offset += result.count
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func loadMore() async {
        await loadPlaylists(reset: false)
    }
}

struct PlaylistGridItem: View {
    @EnvironmentObject private var appModel: AppModel
    let playlist: MAPlaylist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(urlString: playlist.artworkPath, baseURL: appModel.settings.serverURL)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let owner = playlist.owner {
                    Text(owner)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Playlist Detail View

struct PlaylistDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let playlist: MAPlaylist
    @State private var tracks: [MATrack] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Playlist Header
                VStack(spacing: 12) {
                    ArtworkView(
                        urlString: playlist.artworkPath, baseURL: appModel.settings.serverURL
                    )
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    VStack(spacing: 4) {
                        Text(playlist.name)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)

                        if let owner = playlist.owner {
                            Text(owner)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text("\(tracks.count) tracks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        Button {
                            Task { await playPlaylist(shuffle: false) }
                        } label: {
                            Label("Play", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)

                        Button {
                            Task { await playPlaylist(shuffle: true) }
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .padding(.top)

                // Track List
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRow(track: track) {
                                Task { await playTrack(track) }
                            }
                            if index < tracks.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTracks() }
    }

    private func loadTracks() async {
        guard let api = appModel.api, let itemID = playlist.itemID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            tracks = try await api.execute(
                command: "music/playlists/playlist_tracks",
                args: [
                    "item_id": .string(itemID),
                    "provider_instance_id_or_domain": .string(playlist.provider ?? "library"),
                ],
                as: [MATrack].self
            )
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func playPlaylist(shuffle: Bool) async {
        await appModel.playPlaylist(playlist, shuffle: shuffle)
    }

    private func playTrack(_ track: MATrack) async {
        await appModel.playTrack(track)
    }
}

// MARK: - Radio List View

struct RadioListView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var stations: [MARadio] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMore = true
    private let pageSize = 50

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(stations) { station in
                    RadioGridItem(station: station) {
                        Task { await playStation(station) }
                    }
                    .onAppear {
                        if station == stations.last && hasMore && !isLoading {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            .padding()

            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .navigationTitle("Radio")
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) {
            Task {
                offset = 0
                hasMore = true
                await loadStations(reset: true)
            }
        }
        .onChange(of: search) { _, newValue in
            if newValue.isEmpty {
                Task {
                    offset = 0
                    hasMore = true
                    await loadStations(reset: true)
                }
            }
        }
        .task { await loadStations(reset: true) }
        .refreshable { await loadStations(reset: true) }
    }

    private func loadStations(reset: Bool) async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        if reset {
            offset = 0
            hasMore = true
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await api.execute(
                command: "music/radio/library_items",
                args: [
                    "search": search.isEmpty ? .null : .string(search),
                    "limit": .int(pageSize),
                    "offset": .int(offset),
                ],
                as: [MARadio].self
            )
            if reset {
                stations = result
            } else {
                stations.append(contentsOf: result)
            }
            hasMore = result.count >= pageSize
            offset += result.count
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func loadMore() async {
        await loadStations(reset: false)
    }

    private func playStation(_ station: MARadio) async {
        await appModel.playRadio(station)
    }
}

struct RadioGridItem: View {
    @EnvironmentObject private var appModel: AppModel
    let station: MARadio
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ArtworkView(urlString: station.artworkPath, baseURL: appModel.settings.serverURL)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                Text(station.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Audiobooks List View

struct AudiobooksListView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var audiobooks: [MAAudiobook] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMore = true
    private let pageSize = 50

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(audiobooks) { audiobook in
                    NavigationLink(destination: AudiobookDetailView(audiobook: audiobook)) {
                        AudiobookGridItem(audiobook: audiobook)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if audiobook == audiobooks.last && hasMore && !isLoading {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            .padding()

            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .navigationTitle("Audiobooks")
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) {
            Task {
                offset = 0
                hasMore = true
                await loadAudiobooks(reset: true)
            }
        }
        .onChange(of: search) { _, newValue in
            if newValue.isEmpty {
                Task {
                    offset = 0
                    hasMore = true
                    await loadAudiobooks(reset: true)
                }
            }
        }
        .task { await loadAudiobooks(reset: true) }
        .refreshable { await loadAudiobooks(reset: true) }
    }

    private func loadAudiobooks(reset: Bool) async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        if reset {
            offset = 0
            hasMore = true
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await api.execute(
                command: "music/audiobooks/library_items",
                args: [
                    "search": search.isEmpty ? .null : .string(search),
                    "limit": .int(pageSize),
                    "offset": .int(offset),
                ],
                as: [MAAudiobook].self
            )
            if reset {
                audiobooks = result
            } else {
                audiobooks.append(contentsOf: result)
            }
            hasMore = result.count >= pageSize
            offset += result.count
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func loadMore() async {
        await loadAudiobooks(reset: false)
    }
}

struct AudiobookGridItem: View {
    @EnvironmentObject private var appModel: AppModel
    let audiobook: MAAudiobook

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(
                urlString: audiobook.artworkPath,
                baseURL: appModel.settings.serverURL,
                cornerRadius: 8,
                placeholderIcon: "book.fill"
            )
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(audiobook.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if let author = audiobook.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Audiobook Detail View

struct AudiobookDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let audiobook: MAAudiobook

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Audiobook Header
                VStack(spacing: 12) {
                    ArtworkView(
                        urlString: audiobook.artworkPath,
                        baseURL: appModel.settings.serverURL,
                        cornerRadius: 12,
                        placeholderIcon: "book.fill"
                    )
                    .frame(width: 220, height: 220)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    VStack(spacing: 4) {
                        Text(audiobook.name)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)

                        if let author = audiobook.author {
                            Text(author)
                                .font(.title3)
                                .foregroundStyle(.pink)
                        }

                        if let narrator = audiobook.narrator {
                            Text("Narrated by \(narrator)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let duration = audiobook.totalDuration {
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task { await playAudiobook() }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(width: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                }
                .padding(.top)
            }
        }
        .navigationTitle(audiobook.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playAudiobook() async {
        guard let uri = audiobook.uri else { return }
        await appModel.playMedia(uri: uri)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}
