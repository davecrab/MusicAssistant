import Foundation

// MARK: - Playback Enums

enum MAPlaybackState: String, Codable, Hashable {
    case idle
    case paused
    case playing
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = MAPlaybackState(rawValue: value) ?? .unknown
    }
}

enum MARepeatMode: String, Codable, Hashable {
    case off
    case one
    case all
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = MARepeatMode(rawValue: value) ?? .unknown
    }
}

enum MAMediaType: String, Codable, Hashable {
    case artist
    case album
    case track
    case playlist
    case radio
    case audiobook
    case folder
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = MAMediaType(rawValue: value) ?? .unknown
    }
}

// MARK: - Player Models

struct MAPlayer: Identifiable, Decodable, Hashable {
    var id: String { playerID }

    let playerID: String
    let name: String
    let available: Bool
    let playbackState: MAPlaybackState
    let volumeLevel: Int?
    let volumeMuted: Bool?
    let groupMembers: [String]
    let syncedTo: String?
    let activeGroup: String?
    let currentMedia: MAPlayerMedia?
    let type: String?
    let icon: String?

    init(
        playerID: String,
        name: String,
        available: Bool,
        playbackState: MAPlaybackState,
        volumeLevel: Int?,
        volumeMuted: Bool?,
        groupMembers: [String],
        syncedTo: String?,
        activeGroup: String?,
        currentMedia: MAPlayerMedia?,
        type: String? = nil,
        icon: String? = nil
    ) {
        self.playerID = playerID
        self.name = name
        self.available = available
        self.playbackState = playbackState
        self.volumeLevel = volumeLevel
        self.volumeMuted = volumeMuted
        self.groupMembers = groupMembers
        self.syncedTo = syncedTo
        self.activeGroup = activeGroup
        self.currentMedia = currentMedia
        self.type = type
        self.icon = icon
    }

    private enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case name
        case available
        case playbackState = "state"
        case volumeLevel = "volume_level"
        case volumeMuted = "volume_muted"
        case groupMembers = "group_childs"
        case syncedTo = "synced_to"
        case activeGroup = "active_group"
        case currentMedia = "current_media"
        case type
        case icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerID = try container.decode(String.self, forKey: .playerID)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown Player"
        available = (try? container.decode(Bool.self, forKey: .available)) ?? false
        playbackState =
            (try? container.decode(MAPlaybackState.self, forKey: .playbackState)) ?? .unknown
        volumeLevel = try? container.decode(Int.self, forKey: .volumeLevel)
        volumeMuted = try? container.decode(Bool.self, forKey: .volumeMuted)
        groupMembers = (try? container.decode([String].self, forKey: .groupMembers)) ?? []
        syncedTo = try? container.decode(String.self, forKey: .syncedTo)
        activeGroup = try? container.decode(String.self, forKey: .activeGroup)
        currentMedia = try? container.decode(MAPlayerMedia.self, forKey: .currentMedia)
        type = try? container.decode(String.self, forKey: .type)
        icon = try? container.decode(String.self, forKey: .icon)
    }
}

struct MAPlayerMedia: Decodable, Hashable {
    let uri: String
    let title: String?
    let artist: String?
    let album: String?
    let imageURL: String?
    let duration: Int?

    init(
        uri: String,
        title: String?,
        artist: String?,
        album: String?,
        imageURL: String?,
        duration: Int?
    ) {
        self.uri = uri
        self.title = title
        self.artist = artist
        self.album = album
        self.imageURL = imageURL
        self.duration = duration
    }

    private enum CodingKeys: String, CodingKey {
        case uri
        case title
        case artist
        case album
        case imageURL = "image_url"
        case duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uri = (try? container.decode(String.self, forKey: .uri)) ?? ""
        title = try? container.decode(String.self, forKey: .title)
        artist = try? container.decode(String.self, forKey: .artist)
        album = try? container.decode(String.self, forKey: .album)
        imageURL = try? container.decode(String.self, forKey: .imageURL)
        duration = try? container.decode(Int.self, forKey: .duration)
    }
}

// MARK: - Stream Details

struct MAStreamDetails: Decodable, Hashable {
    let provider: String
    let itemID: String

    private enum CodingKeys: String, CodingKey {
        case provider
        case itemID = "item_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = (try? container.decode(String.self, forKey: .provider)) ?? ""
        itemID = (try? container.decode(String.self, forKey: .itemID)) ?? ""
    }
}

// MARK: - Queue Models

struct MAPlayerQueue: Identifiable, Decodable, Hashable {
    var id: String { queueID }

    let queueID: String
    let active: Bool
    let displayName: String
    let available: Bool
    let items: Int
    let shuffleEnabled: Bool
    let repeatMode: MARepeatMode
    let currentIndex: Int?
    let elapsedTime: Double
    let state: MAPlaybackState
    let currentItem: MAQueueItem?

    init(
        queueID: String,
        active: Bool,
        displayName: String,
        available: Bool,
        items: Int,
        shuffleEnabled: Bool,
        repeatMode: MARepeatMode,
        currentIndex: Int?,
        elapsedTime: Double,
        state: MAPlaybackState,
        currentItem: MAQueueItem?
    ) {
        self.queueID = queueID
        self.active = active
        self.displayName = displayName
        self.available = available
        self.items = items
        self.shuffleEnabled = shuffleEnabled
        self.repeatMode = repeatMode
        self.currentIndex = currentIndex
        self.elapsedTime = elapsedTime
        self.state = state
        self.currentItem = currentItem
    }

    private enum CodingKeys: String, CodingKey {
        case queueID = "queue_id"
        case active
        case displayName = "display_name"
        case available
        case items
        case shuffleEnabled = "shuffle_enabled"
        case repeatMode = "repeat_mode"
        case currentIndex = "current_index"
        case elapsedTime = "elapsed_time"
        case state
        case currentItem = "current_item"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        queueID = try container.decode(String.self, forKey: .queueID)
        active = (try? container.decode(Bool.self, forKey: .active)) ?? false
        displayName = (try? container.decode(String.self, forKey: .displayName)) ?? ""
        available = (try? container.decode(Bool.self, forKey: .available)) ?? false
        items = (try? container.decode(Int.self, forKey: .items)) ?? 0
        shuffleEnabled = (try? container.decode(Bool.self, forKey: .shuffleEnabled)) ?? false
        repeatMode = (try? container.decode(MARepeatMode.self, forKey: .repeatMode)) ?? .off
        currentIndex = try? container.decode(Int.self, forKey: .currentIndex)
        elapsedTime = (try? container.decode(Double.self, forKey: .elapsedTime)) ?? 0
        state = (try? container.decode(MAPlaybackState.self, forKey: .state)) ?? .idle
        currentItem = try? container.decode(MAQueueItem.self, forKey: .currentItem)
    }
}

struct MAQueueItem: Identifiable, Decodable, Hashable {
    var id: String { queueItemID }

    let queueID: String
    let queueItemID: String
    let name: String
    let duration: Int?
    let image: MAMediaItemImage?
    let mediaItem: MATrack?
    let streamDetails: MAStreamDetails?

    private enum CodingKeys: String, CodingKey {
        case queueID = "queue_id"
        case queueItemID = "queue_item_id"
        case name
        case duration
        case image
        case mediaItem = "media_item"
        case streamDetails = "streamdetails"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        queueID = (try? container.decode(String.self, forKey: .queueID)) ?? ""
        queueItemID =
            (try? container.decode(String.self, forKey: .queueItemID)) ?? UUID().uuidString
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        duration = try? container.decode(Int.self, forKey: .duration)
        image = try? container.decode(MAMediaItemImage.self, forKey: .image)
        mediaItem = try? container.decode(MATrack.self, forKey: .mediaItem)
        streamDetails = try? container.decode(MAStreamDetails.self, forKey: .streamDetails)
    }
}

// MARK: - Media Item Image

struct MAMediaItemImage: Decodable, Hashable {
    let path: String?
    let url: String?
    let type: String?
    let remotelyCacheable: Bool?

    var resolvedPath: String? {
        url ?? path
    }

    private enum CodingKeys: String, CodingKey {
        case path
        case url
        case type
        case remotelyCacheable = "remotely_cacheable"
    }

    init(
        path: String? = nil, url: String? = nil, type: String? = nil, remotelyCacheable: Bool? = nil
    ) {
        self.path = path
        self.url = url
        self.type = type
        self.remotelyCacheable = remotelyCacheable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try? container.decode(String.self, forKey: .path)
        url = try? container.decode(String.self, forKey: .url)
        type = try? container.decode(String.self, forKey: .type)
        remotelyCacheable = try? container.decode(Bool.self, forKey: .remotelyCacheable)
    }
}

// MARK: - Provider Mapping

struct MAProviderMapping: Decodable, Hashable {
    let itemID: String
    let providerDomain: String
    let providerInstance: String
    let available: Bool
    let url: String?

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case providerDomain = "provider_domain"
        case providerInstance = "provider_instance"
        case available
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemID = (try? container.decode(String.self, forKey: .itemID)) ?? ""
        providerDomain = (try? container.decode(String.self, forKey: .providerDomain)) ?? ""
        providerInstance = (try? container.decode(String.self, forKey: .providerInstance)) ?? ""
        available = (try? container.decode(Bool.self, forKey: .available)) ?? false
        url = try? container.decode(String.self, forKey: .url)
    }
}

// MARK: - Track Model

struct MATrack: Identifiable, Decodable, Hashable {
    var id: String { stableID }

    let itemID: String?
    let provider: String?
    let name: String
    let uri: String?
    let favorite: Bool
    let metadata: MAMediaItemMetadata
    let duration: Int?
    let image: MAMediaItemImage?
    let artists: [MAArtist]?
    let album: MAAlbum?
    let providerMappings: [MAProviderMapping]?
    let trackNumber: Int?
    let discNumber: Int?

    var stableID: String {
        itemID ?? uri ?? "\(provider ?? "unknown")|\(name)"
    }

    var artistName: String {
        if let artists = artists, !artists.isEmpty {
            return artists.map { $0.name }.joined(separator: ", ")
        }
        return metadata.artist ?? ""
    }

    var albumName: String {
        album?.name ?? metadata.album ?? ""
    }

    var artworkPath: String? {
        image?.resolvedPath ?? metadata.images?.first?.resolvedPath ?? album?.image?.resolvedPath
    }

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case provider
        case name
        case uri
        case favorite
        case metadata
        case duration
        case image
        case artists
        case album
        case providerMappings = "provider_mappings"
        case trackNumber = "track_number"
        case discNumber = "disc_number"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try? container.decode(String.self, forKey: .itemID)
        provider = try? container.decode(String.self, forKey: .provider)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        uri = try? container.decode(String.self, forKey: .uri)
        favorite = (try? container.decode(Bool.self, forKey: .favorite)) ?? false
        metadata = (try? container.decode(MAMediaItemMetadata.self, forKey: .metadata)) ?? .empty
        duration = try? container.decode(Int.self, forKey: .duration)
        image = try? container.decode(MAMediaItemImage.self, forKey: .image)
        artists = try? container.decode([MAArtist].self, forKey: .artists)
        album = try? container.decode(MAAlbum.self, forKey: .album)
        providerMappings = try? container.decode(
            [MAProviderMapping].self, forKey: .providerMappings)
        trackNumber = try? container.decode(Int.self, forKey: .trackNumber)
        discNumber = try? container.decode(Int.self, forKey: .discNumber)
    }
}

// MARK: - Album Model

struct MAAlbum: Identifiable, Decodable, Hashable {
    var id: String { stableID }

    let itemID: String?
    let provider: String?
    let name: String
    let uri: String?
    let favorite: Bool
    let image: MAMediaItemImage?
    let artists: [MAArtist]?
    let year: Int?
    let version: String?
    let albumType: String?
    let providerMappings: [MAProviderMapping]?

    var stableID: String {
        itemID ?? uri ?? "\(provider ?? "unknown")|\(name)"
    }

    var artistName: String {
        artists?.map { $0.name }.joined(separator: ", ") ?? ""
    }

    var artworkPath: String? {
        image?.resolvedPath
    }

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case provider
        case name
        case uri
        case favorite
        case image
        case artists
        case year
        case version
        case albumType = "album_type"
        case providerMappings = "provider_mappings"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try? container.decode(String.self, forKey: .itemID)
        provider = try? container.decode(String.self, forKey: .provider)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown Album"
        uri = try? container.decode(String.self, forKey: .uri)
        favorite = (try? container.decode(Bool.self, forKey: .favorite)) ?? false
        image = try? container.decode(MAMediaItemImage.self, forKey: .image)
        artists = try? container.decode([MAArtist].self, forKey: .artists)
        year = try? container.decode(Int.self, forKey: .year)
        version = try? container.decode(String.self, forKey: .version)
        albumType = try? container.decode(String.self, forKey: .albumType)
        providerMappings = try? container.decode(
            [MAProviderMapping].self, forKey: .providerMappings)
    }

    init(
        itemID: String?, provider: String?, name: String, uri: String?, favorite: Bool,
        image: MAMediaItemImage?, artists: [MAArtist]?, year: Int?, version: String?,
        albumType: String?, providerMappings: [MAProviderMapping]?
    ) {
        self.itemID = itemID
        self.provider = provider
        self.name = name
        self.uri = uri
        self.favorite = favorite
        self.image = image
        self.artists = artists
        self.year = year
        self.version = version
        self.albumType = albumType
        self.providerMappings = providerMappings
    }
}

// MARK: - Artist Model

struct MAArtist: Identifiable, Decodable, Hashable {
    var id: String { stableID }

    let itemID: String?
    let provider: String?
    let name: String
    let uri: String?
    let favorite: Bool
    let image: MAMediaItemImage?
    let providerMappings: [MAProviderMapping]?

    var stableID: String {
        itemID ?? uri ?? "\(provider ?? "unknown")|\(name)"
    }

    var artworkPath: String? {
        image?.resolvedPath
    }

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case provider
        case name
        case uri
        case favorite
        case image
        case providerMappings = "provider_mappings"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try? container.decode(String.self, forKey: .itemID)
        provider = try? container.decode(String.self, forKey: .provider)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown Artist"
        uri = try? container.decode(String.self, forKey: .uri)
        favorite = (try? container.decode(Bool.self, forKey: .favorite)) ?? false
        image = try? container.decode(MAMediaItemImage.self, forKey: .image)
        providerMappings = try? container.decode(
            [MAProviderMapping].self, forKey: .providerMappings)
    }

    init(
        itemID: String?, provider: String?, name: String, uri: String?, favorite: Bool,
        image: MAMediaItemImage?, providerMappings: [MAProviderMapping]?
    ) {
        self.itemID = itemID
        self.provider = provider
        self.name = name
        self.uri = uri
        self.favorite = favorite
        self.image = image
        self.providerMappings = providerMappings
    }
}

// MARK: - Playlist Model

struct MAPlaylist: Identifiable, Decodable, Hashable {
    var id: String { stableID }

    let itemID: String?
    let provider: String?
    let name: String
    let uri: String?
    let favorite: Bool
    let image: MAMediaItemImage?
    let owner: String?
    let isEditable: Bool
    let providerMappings: [MAProviderMapping]?

    var stableID: String {
        itemID ?? uri ?? "\(provider ?? "unknown")|\(name)"
    }

    var artworkPath: String? {
        image?.resolvedPath
    }

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case provider
        case name
        case uri
        case favorite
        case image
        case owner
        case isEditable = "is_editable"
        case providerMappings = "provider_mappings"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try? container.decode(String.self, forKey: .itemID)
        provider = try? container.decode(String.self, forKey: .provider)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown Playlist"
        uri = try? container.decode(String.self, forKey: .uri)
        favorite = (try? container.decode(Bool.self, forKey: .favorite)) ?? false
        image = try? container.decode(MAMediaItemImage.self, forKey: .image)
        owner = try? container.decode(String.self, forKey: .owner)
        isEditable = (try? container.decode(Bool.self, forKey: .isEditable)) ?? false
        providerMappings = try? container.decode(
            [MAProviderMapping].self, forKey: .providerMappings)
    }
}

// MARK: - Radio Model

struct MARadio: Identifiable, Decodable, Hashable {
    var id: String { stableID }

    let itemID: String?
    let provider: String?
    let name: String
    let uri: String?
    let favorite: Bool
    let image: MAMediaItemImage?
    let providerMappings: [MAProviderMapping]?

    var stableID: String {
        itemID ?? uri ?? "\(provider ?? "unknown")|\(name)"
    }

    var artworkPath: String? {
        image?.resolvedPath
    }

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case provider
        case name
        case uri
        case favorite
        case image
        case providerMappings = "provider_mappings"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try? container.decode(String.self, forKey: .itemID)
        provider = try? container.decode(String.self, forKey: .provider)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown Radio"
        uri = try? container.decode(String.self, forKey: .uri)
        favorite = (try? container.decode(Bool.self, forKey: .favorite)) ?? false
        image = try? container.decode(MAMediaItemImage.self, forKey: .image)
        providerMappings = try? container.decode(
            [MAProviderMapping].self, forKey: .providerMappings)
    }
}

// MARK: - Metadata

struct MAMediaItemMetadata: Decodable, Hashable {
    let artist: String?
    let album: String?
    let images: [MAMediaItemImage]?
    let genres: [String]?
    let description: String?

    static let empty = MAMediaItemMetadata(
        artist: nil, album: nil, images: nil, genres: nil, description: nil)

    init(
        artist: String?, album: String?, images: [MAMediaItemImage]?, genres: [String]? = nil,
        description: String? = nil
    ) {
        self.artist = artist
        self.album = album
        self.images = images
        self.genres = genres
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artist = try? container.decode(String.self, forKey: .artist)
        album = try? container.decode(String.self, forKey: .album)
        images = try? container.decode([MAMediaItemImage].self, forKey: .images)
        genres = try? container.decode([String].self, forKey: .genres)
        description = try? container.decode(String.self, forKey: .description)
    }

    private enum CodingKeys: String, CodingKey {
        case artist
        case album
        case images
        case genres
        case description
    }
}

// MARK: - Browse Item (for provider browsing)

struct MABrowseItem: Identifiable, Decodable, Hashable {
    var id: String { path ?? uri ?? UUID().uuidString }

    let itemId: String?
    let provider: String?
    let path: String?
    let name: String
    let label: String?
    let mediaType: MAMediaType?
    let image: MAMediaItemImage?
    let uri: String?
    let isExpandable: Bool
    let isPlayable: Bool
    let favorite: Bool

    var artworkPath: String? {
        image?.resolvedPath
    }

    /// Check if this item is a folder that can be browsed
    var isFolder: Bool {
        mediaType == .folder || isExpandable
    }

    /// Check if this is a playable media item (track, radio, audiobook, etc.)
    var canPlay: Bool {
        isPlayable || (mediaType == .track || mediaType == .radio || mediaType == .audiobook)
    }

    private enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case provider
        case path
        case name
        case label
        case mediaType = "media_type"
        case image
        case uri
        case isExpandable = "is_expandable"
        case isPlayable = "is_playable"
        case favorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try? container.decode(String.self, forKey: .itemId)
        provider = try? container.decode(String.self, forKey: .provider)
        path = try? container.decode(String.self, forKey: .path)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        label = try? container.decode(String.self, forKey: .label)
        mediaType = try? container.decode(MAMediaType.self, forKey: .mediaType)
        image = try? container.decode(MAMediaItemImage.self, forKey: .image)
        uri = try? container.decode(String.self, forKey: .uri)
        isExpandable = (try? container.decode(Bool.self, forKey: .isExpandable)) ?? false
        isPlayable = (try? container.decode(Bool.self, forKey: .isPlayable)) ?? false
        favorite = (try? container.decode(Bool.self, forKey: .favorite)) ?? false
    }
}

// MARK: - Provider Info

struct MAProvider: Identifiable, Decodable, Hashable {
    var id: String { instanceID }

    let instanceID: String
    let domain: String
    let name: String
    let icon: String?
    let available: Bool

    private enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case domain
        case name
        case icon
        case available
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceID = (try? container.decode(String.self, forKey: .instanceID)) ?? UUID().uuidString
        domain = (try? container.decode(String.self, forKey: .domain)) ?? ""
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown Provider"
        icon = try? container.decode(String.self, forKey: .icon)
        available = (try? container.decode(Bool.self, forKey: .available)) ?? false
    }
}

// MARK: - Library Category

enum LibraryCategory: String, CaseIterable, Identifiable {
    case albums
    case artists
    case tracks
    case playlists
    case audiobooks
    case radio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .albums: return "Albums"
        case .artists: return "Artists"
        case .tracks: return "Tracks"
        case .playlists: return "Playlists"
        case .audiobooks: return "Audiobooks"
        case .radio: return "Radio"
        }
    }

    var icon: String {
        switch self {
        case .albums: return "square.stack"
        case .artists: return "music.mic"
        case .tracks: return "music.note"
        case .playlists: return "music.note.list"
        case .audiobooks: return "book.fill"
        case .radio: return "radio"
        }
    }

    var apiCommand: String {
        switch self {
        case .albums: return "music/albums/library_items"
        case .artists: return "music/artists/library_items"
        case .tracks: return "music/tracks/library_items"
        case .playlists: return "music/playlists/library_items"
        case .audiobooks: return "music/audiobooks/library_items"
        case .radio: return "music/radio/library_items"
        }
    }
}

// MARK: - Audiobook Model

struct MAAudiobook: Identifiable, Decodable, Hashable {
    var id: String { stableID }

    let itemID: String?
    let provider: String?
    let name: String
    let uri: String?
    let favorite: Bool
    let image: MAMediaItemImage?
    let authors: [String]
    let narrators: [String]
    let publisher: String?
    let duration: Int?
    let fullyPlayed: Bool?
    let resumePositionMs: Int?
    let providerMappings: [MAProviderMapping]?

    var stableID: String {
        itemID ?? uri ?? "\(provider ?? "unknown")|\(name)"
    }

    var artworkPath: String? {
        image?.resolvedPath
    }

    /// Convenience property for displaying primary author
    var author: String? {
        authors.first
    }

    /// Convenience property for displaying primary narrator
    var narrator: String? {
        narrators.first
    }

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case provider
        case name
        case uri
        case favorite
        case image
        case authors
        case narrators
        case publisher
        case duration
        case fullyPlayed = "fully_played"
        case resumePositionMs = "resume_position_ms"
        case providerMappings = "provider_mappings"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try? container.decode(String.self, forKey: .itemID)
        provider = try? container.decode(String.self, forKey: .provider)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown Audiobook"
        uri = try? container.decode(String.self, forKey: .uri)
        favorite = (try? container.decode(Bool.self, forKey: .favorite)) ?? false
        image = try? container.decode(MAMediaItemImage.self, forKey: .image)
        authors = (try? container.decode([String].self, forKey: .authors)) ?? []
        narrators = (try? container.decode([String].self, forKey: .narrators)) ?? []
        publisher = try? container.decode(String.self, forKey: .publisher)
        duration = try? container.decode(Int.self, forKey: .duration)
        fullyPlayed = try? container.decode(Bool.self, forKey: .fullyPlayed)
        resumePositionMs = try? container.decode(Int.self, forKey: .resumePositionMs)
        providerMappings = try? container.decode(
            [MAProviderMapping].self, forKey: .providerMappings)
    }
}

// MARK: - Provider Type Enum

enum MAProviderType: String, Codable, Hashable, CaseIterable {
    case music
    case player
    case metadata
    case plugin
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = MAProviderType(rawValue: value) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .music: return "Music Provider"
        case .player: return "Player Provider"
        case .metadata: return "Metadata Provider"
        case .plugin: return "Plugin"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .player: return "speaker.wave.2"
        case .metadata: return "info.circle"
        case .plugin: return "puzzlepiece"
        case .unknown: return "questionmark"
        }
    }
}

// MARK: - Provider Stage Enum

enum MAProviderStage: String, Codable, Hashable {
    case alpha
    case beta
    case stable
    case experimental
    case unmaintained
    case deprecated
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = MAProviderStage(rawValue: value) ?? .unknown
    }

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .stable: return "green"
        case .beta: return "blue"
        case .alpha: return "orange"
        case .experimental: return "purple"
        case .unmaintained: return "gray"
        case .deprecated: return "red"
        case .unknown: return "gray"
        }
    }
}

// MARK: - Config Entry Type Enum

enum MAConfigEntryType: String, Codable, Hashable {
    case boolean
    case string
    case secureString = "secure_string"
    case integer
    case float
    case label
    case divider
    case action
    case icon
    case alert
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = MAConfigEntryType(rawValue: value) ?? .unknown
    }
}

// MARK: - Provider Manifest

struct MAProviderManifest: Identifiable, Decodable, Hashable {
    var id: String { domain }

    let type: MAProviderType
    let domain: String
    let name: String
    let description: String
    let codeowners: [String]
    let credits: [String]
    let requirements: [String]
    let documentation: String?
    let multiInstance: Bool
    let builtin: Bool
    let allowDisable: Bool
    let stage: MAProviderStage
    let icon: String?
    let iconSvg: String?
    let iconSvgDark: String?
    let iconSvgMonochrome: String?
    let dependsOn: String?

    enum CodingKeys: String, CodingKey {
        case type
        case domain
        case name
        case description
        case codeowners
        case credits
        case requirements
        case documentation
        case multiInstance = "multi_instance"
        case builtin
        case allowDisable = "allow_disable"
        case stage
        case icon
        case iconSvg = "icon_svg"
        case iconSvgDark = "icon_svg_dark"
        case iconSvgMonochrome = "icon_svg_monochrome"
        case dependsOn = "depends_on"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decode(MAProviderType.self, forKey: .type)) ?? .unknown
        domain = (try? container.decode(String.self, forKey: .domain)) ?? ""
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        description = (try? container.decode(String.self, forKey: .description)) ?? ""
        codeowners = (try? container.decode([String].self, forKey: .codeowners)) ?? []
        credits = (try? container.decode([String].self, forKey: .credits)) ?? []
        requirements = (try? container.decode([String].self, forKey: .requirements)) ?? []
        documentation = try? container.decode(String.self, forKey: .documentation)
        multiInstance = (try? container.decode(Bool.self, forKey: .multiInstance)) ?? false
        builtin = (try? container.decode(Bool.self, forKey: .builtin)) ?? false
        allowDisable = (try? container.decode(Bool.self, forKey: .allowDisable)) ?? true
        stage = (try? container.decode(MAProviderStage.self, forKey: .stage)) ?? .unknown
        icon = try? container.decode(String.self, forKey: .icon)
        iconSvg = try? container.decode(String.self, forKey: .iconSvg)
        iconSvgDark = try? container.decode(String.self, forKey: .iconSvgDark)
        iconSvgMonochrome = try? container.decode(String.self, forKey: .iconSvgMonochrome)
        dependsOn = try? container.decode(String.self, forKey: .dependsOn)
    }
}

// MARK: - Config Value Option

struct MAConfigValueOption: Decodable, Hashable {
    let title: String
    let value: AnyCodable

    enum CodingKeys: String, CodingKey {
        case title
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        value = (try? container.decode(AnyCodable.self, forKey: .value)) ?? AnyCodable("")
    }
}

// MARK: - Config Entry

struct MAConfigEntry: Identifiable, Decodable, Hashable {
    var id: String { key }

    let key: String
    let type: MAConfigEntryType
    let label: String
    let defaultValue: AnyCodable?
    let required: Bool
    let options: [MAConfigValueOption]?
    let range: [Double]?
    let description: String?
    let helpLink: String?
    let multiValue: Bool
    let dependsOn: String?
    let dependsOnValue: AnyCodable?
    let dependsOnValueNot: AnyCodable?
    let hidden: Bool
    let readOnly: Bool
    let category: String
    let action: String?
    let actionLabel: String?
    let immediateApply: Bool
    var value: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case key
        case type
        case label
        case defaultValue = "default_value"
        case required
        case options
        case range
        case description
        case helpLink = "help_link"
        case multiValue = "multi_value"
        case dependsOn = "depends_on"
        case dependsOnValue = "depends_on_value"
        case dependsOnValueNot = "depends_on_value_not"
        case hidden
        case readOnly = "read_only"
        case category
        case action
        case actionLabel = "action_label"
        case immediateApply = "immediate_apply"
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = (try? container.decode(String.self, forKey: .key)) ?? ""
        type = (try? container.decode(MAConfigEntryType.self, forKey: .type)) ?? .unknown
        label = (try? container.decode(String.self, forKey: .label)) ?? ""
        defaultValue = try? container.decode(AnyCodable.self, forKey: .defaultValue)
        required = (try? container.decode(Bool.self, forKey: .required)) ?? false
        options = try? container.decode([MAConfigValueOption].self, forKey: .options)
        range = try? container.decode([Double].self, forKey: .range)
        description = try? container.decode(String.self, forKey: .description)
        helpLink = try? container.decode(String.self, forKey: .helpLink)
        multiValue = (try? container.decode(Bool.self, forKey: .multiValue)) ?? false
        dependsOn = try? container.decode(String.self, forKey: .dependsOn)
        dependsOnValue = try? container.decode(AnyCodable.self, forKey: .dependsOnValue)
        dependsOnValueNot = try? container.decode(AnyCodable.self, forKey: .dependsOnValueNot)
        hidden = (try? container.decode(Bool.self, forKey: .hidden)) ?? false
        readOnly = (try? container.decode(Bool.self, forKey: .readOnly)) ?? false
        category = (try? container.decode(String.self, forKey: .category)) ?? "generic"
        action = try? container.decode(String.self, forKey: .action)
        actionLabel = try? container.decode(String.self, forKey: .actionLabel)
        immediateApply = (try? container.decode(Bool.self, forKey: .immediateApply)) ?? false
        value = try? container.decode(AnyCodable.self, forKey: .value)
    }

    // Helper to get current value or default
    var effectiveValue: AnyCodable? {
        value ?? defaultValue
    }

    var stringValue: String {
        effectiveValue?.stringValue ?? ""
    }

    var boolValue: Bool {
        effectiveValue?.boolValue ?? false
    }

    var intValue: Int {
        effectiveValue?.intValue ?? 0
    }

    var doubleValue: Double {
        effectiveValue?.doubleValue ?? 0.0
    }
}

// MARK: - Provider Config

struct MAProviderConfig: Identifiable, Decodable, Hashable {
    var id: String { instanceID }

    let type: MAProviderType
    let domain: String
    let instanceID: String
    let manifest: MAProviderManifest?
    let enabled: Bool
    let name: String?
    let lastError: String?
    let values: [String: MAConfigEntry]

    enum CodingKeys: String, CodingKey {
        case type
        case domain
        case instanceID = "instance_id"
        case manifest
        case enabled
        case name
        case lastError = "last_error"
        case values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decode(MAProviderType.self, forKey: .type)) ?? .unknown
        domain = (try? container.decode(String.self, forKey: .domain)) ?? ""
        instanceID = (try? container.decode(String.self, forKey: .instanceID)) ?? ""
        manifest = try? container.decode(MAProviderManifest.self, forKey: .manifest)
        enabled = (try? container.decode(Bool.self, forKey: .enabled)) ?? false
        name = try? container.decode(String.self, forKey: .name)
        lastError = try? container.decode(String.self, forKey: .lastError)
        values = (try? container.decode([String: MAConfigEntry].self, forKey: .values)) ?? [:]
    }

    var displayName: String {
        name ?? manifest?.name ?? domain
    }

    var hasError: Bool {
        lastError != nil && enabled
    }
}

// MARK: - Player Config

struct MAPlayerConfig: Identifiable, Decodable, Hashable {
    var id: String { playerID }

    let provider: String
    let playerID: String
    let enabled: Bool
    let name: String?
    let defaultName: String?
    let values: [String: MAConfigEntry]

    enum CodingKeys: String, CodingKey {
        case provider
        case playerID = "player_id"
        case enabled
        case name
        case defaultName = "default_name"
        case values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = (try? container.decode(String.self, forKey: .provider)) ?? ""
        playerID = (try? container.decode(String.self, forKey: .playerID)) ?? ""
        enabled = (try? container.decode(Bool.self, forKey: .enabled)) ?? false
        name = try? container.decode(String.self, forKey: .name)
        defaultName = try? container.decode(String.self, forKey: .defaultName)
        values = (try? container.decode([String: MAConfigEntry].self, forKey: .values)) ?? [:]
    }

    var displayName: String {
        name ?? defaultName ?? playerID
    }
}

// MARK: - Auth Session Event (for OAuth flows)

struct MAAuthSessionEvent: Decodable {
    let sessionID: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "object_id"
        case url = "data"
    }
}
