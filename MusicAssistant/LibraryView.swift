import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Category Pills
                    CategoryPillsSection()

                    // Top Picks Section (large cards like Apple Music)
                    TopPicksSection()

                    // Recently Played Section
                    RecentlyPlayedSection()

                    // Favorite Albums Section
                    FavoritesSection()

                    // Bottom padding for mini player
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Home")
        }
    }
}

// MARK: - Category Pills Section

struct CategoryPillsSection: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LibraryCategory.allCases) { category in
                    NavigationLink(destination: destinationView(for: category)) {
                        CategoryPill(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
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

struct CategoryPill: View {
    let category: LibraryCategory

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.subheadline)

            Text(category.displayName)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Top Picks Section (Large Featured Cards)

struct TopPicksSection: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var featuredAlbums: [MAAlbum] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Picks for You")
                .font(.title2.weight(.bold))
                .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if featuredAlbums.isEmpty {
                Text("Start listening to get personalized picks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(featuredAlbums.prefix(6)) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                FeaturedCard(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task { await loadFeatured() }
    }

    private func loadFeatured() async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            featuredAlbums = try await api.execute(
                command: "music/albums/library_items",
                args: [
                    "limit": .int(10),
                    "offset": .int(0),
                    "order_by": .string("random"),
                ],
                as: [MAAlbum].self
            )
        } catch {
            // Silently fail - this is optional content
        }
    }
}

struct FeaturedCard: View {
    @EnvironmentObject private var appModel: AppModel
    let album: MAAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Large artwork with gradient overlay
            ZStack(alignment: .bottomLeading) {
                ArtworkView(
                    urlString: album.artworkPath,
                    baseURL: appModel.settings.serverURL,
                    cornerRadius: 0
                )
                .frame(width: 280, height: 280)

                // Gradient overlay for text
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .frame(maxHeight: .infinity, alignment: .bottom)

                // Text overlay
                VStack(alignment: .leading, spacing: 4) {
                    Text("Album")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))

                    Text(album.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(12)
            }
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}

// MARK: - Recently Played Section

struct RecentlyPlayedSection: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var recentTracks: [MATrack] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Played")
                    .font(.title2.weight(.bold))

                Spacer()

                if !recentTracks.isEmpty {
                    NavigationLink {
                        RecentlyPlayedListView(tracks: recentTracks)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if recentTracks.isEmpty {
                Text("No recently played tracks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(recentTracks.prefix(10)) { track in
                            RecentTrackCard(track: track) {
                                Task { await playTrack(track) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task { await loadRecentTracks() }
    }

    private func loadRecentTracks() async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            recentTracks = try await api.execute(
                command: "music/tracks/library_items",
                args: [
                    "limit": .int(20),
                    "offset": .int(0),
                    "order_by": .string("timestamp_played"),
                ],
                as: [MATrack].self
            )
        } catch {
            // Silently fail - this is optional content
        }
    }

    private func playTrack(_ track: MATrack) async {
        await appModel.playTrack(track)
    }
}

struct RecentTrackCard: View {
    @EnvironmentObject private var appModel: AppModel
    let track: MATrack
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkView(
                    urlString: track.artworkPath,
                    baseURL: appModel.settings.serverURL,
                    cornerRadius: 8
                )
                .frame(width: 150, height: 150)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text(track.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 150, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct RecentlyPlayedListView: View {
    @EnvironmentObject private var appModel: AppModel
    let tracks: [MATrack]

    var body: some View {
        List {
            ForEach(tracks) { track in
                TrackRow(track: track) {
                    Task { await playTrack(track) }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Recently Played")
    }

    private func playTrack(_ track: MATrack) async {
        await appModel.playTrack(track)
    }
}

// MARK: - Favorites Section

struct FavoritesSection: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var favoriteAlbums: [MAAlbum] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Favorite Albums")
                    .font(.title2.weight(.bold))

                Spacer()

                if !favoriteAlbums.isEmpty {
                    NavigationLink {
                        FavoriteAlbumsListView(albums: favoriteAlbums)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if favoriteAlbums.isEmpty {
                Text("No favorite albums yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(favoriteAlbums.prefix(10)) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                FavoriteAlbumCard(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task { await loadFavorites() }
    }

    private func loadFavorites() async {
        guard let api = appModel.api, appModel.isSignedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            favoriteAlbums = try await api.execute(
                command: "music/albums/library_items",
                args: [
                    "favorite": .bool(true),
                    "limit": .int(20),
                    "offset": .int(0),
                ],
                as: [MAAlbum].self
            )
        } catch {
            // Silently fail - this is optional content
        }
    }
}

struct FavoriteAlbumCard: View {
    @EnvironmentObject private var appModel: AppModel
    let album: MAAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(
                urlString: album.artworkPath,
                baseURL: appModel.settings.serverURL,
                cornerRadius: 8
            )
            .frame(width: 160, height: 160)
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
            .frame(width: 160, alignment: .leading)
        }
    }
}

struct FavoriteAlbumsListView: View {
    let albums: [MAAlbum]

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
                }
            }
            .padding()
        }
        .navigationTitle("Favorite Albums")
    }
}
