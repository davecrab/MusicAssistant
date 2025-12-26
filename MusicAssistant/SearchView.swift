import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var query = ""
    @State private var searchResults = SearchResults()
    @State private var isLoading = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty && !hasSearched {
                    // Empty state with suggestions
                    SearchSuggestionsView(onSelect: { suggestion in
                        query = suggestion
                        Task { await runSearch() }
                    })
                } else if isLoading {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && hasSearched {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No results found for \"\(query)\"")
                    )
                } else {
                    SearchResultsView(results: searchResults)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Artists, Songs, Albums...")
            .onSubmit(of: .search) {
                Task { await runSearch() }
            }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    searchResults = SearchResults()
                    hasSearched = false
                }
            }
        }
    }

    private func runSearch() async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = SearchResults()
            return
        }

        isLoading = true
        hasSearched = true
        defer { isLoading = false }

        do {
            let response = try await api.execute(
                command: "music/search",
                args: [
                    "search_query": .string(trimmedQuery),
                    "media_types": .array([
                        .string("track"),
                        .string("album"),
                        .string("artist"),
                        .string("playlist"),
                        .string("audiobook"),
                    ]),
                    "limit": .int(25),
                ],
                as: SearchResponse.self
            )

            searchResults = SearchResults(
                tracks: response.tracks ?? [],
                albums: response.albums ?? [],
                artists: response.artists ?? [],
                playlists: response.playlists ?? [],
                audiobooks: response.audiobooks ?? []
            )
        } catch {
            appModel.lastError =
                (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

// MARK: - Search Response

struct SearchResponse: Decodable {
    let tracks: [MATrack]?
    let albums: [MAAlbum]?
    let artists: [MAArtist]?
    let playlists: [MAPlaylist]?
    let audiobooks: [MAAudiobook]?
}

struct SearchResults {
    var tracks: [MATrack] = []
    var albums: [MAAlbum] = []
    var artists: [MAArtist] = []
    var playlists: [MAPlaylist] = []
    var audiobooks: [MAAudiobook] = []

    var isEmpty: Bool {
        tracks.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty
            && audiobooks.isEmpty
    }

    var totalCount: Int {
        tracks.count + albums.count + artists.count + playlists.count + audiobooks.count
    }
}

// MARK: - Search Suggestions View

struct SearchSuggestionsView: View {
    let onSelect: (String) -> Void

    private let recentSearches = ["Jazz", "Rock", "Classical", "Pop"]
    private let browseCategories = [
        ("Top Charts", "chart.line.uptrend.xyaxis"),
        ("New Releases", "sparkles"),
        ("Genres", "guitars"),
        ("Moods", "face.smiling"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Browse Categories
                VStack(alignment: .leading, spacing: 12) {
                    Text("Browse")
                        .font(.title2.weight(.bold))
                        .padding(.horizontal)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ],
                        spacing: 12
                    ) {
                        ForEach(browseCategories, id: \.0) { category in
                            BrowseCategoryCard(title: category.0, icon: category.1)
                        }
                    }
                    .padding(.horizontal)
                }

                // Quick Searches
                VStack(alignment: .leading, spacing: 12) {
                    Text("Try Searching")
                        .font(.title2.weight(.bold))
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(recentSearches, id: \.self) { search in
                                Button {
                                    onSelect(search)
                                } label: {
                                    Text(search)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct BrowseCategoryCard: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.pink)
                .frame(width: 32)

            Text(title)
                .font(.subheadline.weight(.medium))

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Search Results View

struct SearchResultsView: View {
    @EnvironmentObject private var appModel: AppModel
    let results: SearchResults

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Artists
                if !results.artists.isEmpty {
                    SearchResultSection(title: "Artists") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(results.artists) { artist in
                                    NavigationLink(destination: ArtistDetailView(artist: artist)) {
                                        SearchArtistCard(artist: artist)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Albums
                if !results.albums.isEmpty {
                    SearchResultSection(title: "Albums") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(results.albums) { album in
                                    NavigationLink(destination: AlbumDetailView(album: album)) {
                                        SearchAlbumCard(album: album)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Playlists
                if !results.playlists.isEmpty {
                    SearchResultSection(title: "Playlists") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(results.playlists) { playlist in
                                    NavigationLink(
                                        destination: PlaylistDetailView(playlist: playlist)
                                    ) {
                                        SearchPlaylistCard(playlist: playlist)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Audiobooks
                if !results.audiobooks.isEmpty {
                    SearchResultSection(title: "Audiobooks") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(results.audiobooks) { audiobook in
                                    NavigationLink(
                                        destination: AudiobookDetailView(audiobook: audiobook)
                                    ) {
                                        SearchAudiobookCard(audiobook: audiobook)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Tracks
                if !results.tracks.isEmpty {
                    SearchResultSection(title: "Songs") {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(results.tracks.enumerated()), id: \.element.id) {
                                index, track in
                                SearchTrackRow(track: track) {
                                    Task { await playTrack(track) }
                                }

                                if index < results.tracks.count - 1 {
                                    Divider()
                                        .padding(.leading, 68)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private func playTrack(_ track: MATrack) async {
        await appModel.playTrack(track)
    }
}

// MARK: - Search Result Section

struct SearchResultSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.bold))
                .padding(.horizontal)

            content()
        }
    }
}

// MARK: - Search Artist Card

struct SearchArtistCard: View {
    @EnvironmentObject private var appModel: AppModel
    let artist: MAArtist

    var body: some View {
        VStack(spacing: 8) {
            ArtworkView(urlString: artist.artworkPath, baseURL: appModel.settings.serverURL)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            Text(artist.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(.primary)
                .frame(width: 120)
        }
    }
}

// MARK: - Search Album Card

struct SearchAlbumCard: View {
    @EnvironmentObject private var appModel: AppModel
    let album: MAAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(urlString: album.artworkPath, baseURL: appModel.settings.serverURL)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(album.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)
        }
    }
}

// MARK: - Search Playlist Card

struct SearchPlaylistCard: View {
    @EnvironmentObject private var appModel: AppModel
    let playlist: MAPlaylist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(urlString: playlist.artworkPath, baseURL: appModel.settings.serverURL)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let owner = playlist.owner {
                    Text(owner)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 140, alignment: .leading)
        }
    }
}

// MARK: - Search Track Row

// MARK: - Search Audiobook Card

struct SearchAudiobookCard: View {
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
            .frame(width: 140, height: 140)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(audiobook.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if let author = audiobook.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 140, alignment: .leading)
        }
    }
}

// MARK: - Search Track Row

struct SearchTrackRow: View {
    @EnvironmentObject private var appModel: AppModel
    let track: MATrack
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArtworkView(urlString: track.artworkPath, baseURL: appModel.settings.serverURL)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text(track.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if !track.albumName.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Text(track.albumName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // More button
                Menu {
                    Button {
                        onTap()
                    } label: {
                        Label("Play Now", systemImage: "play.fill")
                    }

                    Button {
                        // Add to queue action
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
                    }

                    if let album = track.album {
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            Label("Go to Album", systemImage: "square.stack")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
