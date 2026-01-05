# Music Assistant - Swift/SwiftUI Client

A native iOS/macOS client for [Music Assistant](https://music-assistant.io/) written in Swift and SwiftUI.

Music Assistant is a free, opensource media library manager that connects to various music providers and allows you to easily browse and play your music collection on various players.

## Features

- 🎵 **Native SwiftUI Interface** - Beautiful, native iOS/macOS experience
- 🎶 **Multi-Provider Support** - Connect to various music streaming services and local libraries
- 🔊 **Multi-Player Control** - Control multiple audio players and create player groups
- 📱 **Local Device Playback** - Use your iOS device as a player with AVFoundation
- 🎨 **Rich Media Display** - Album artwork, track information, and metadata
- 🔐 **Secure Authentication** - OAuth support with keychain storage
- 📚 **Library Management** - Browse tracks, albums, artists, playlists, audiobooks, and radio stations
- 🔍 **Search** - Quick search across your entire music library
- 🎛️ **Player Configuration** - Configure and manage multiple audio players
- 🔄 **Real-time Updates** - Live playback state and queue management
- 🎯 **Queue Control** - View and manage playback queues
- 🔀 **Shuffle & Repeat** - Full playback control with shuffle and repeat modes

## Requirements

- iOS 15.0+ / macOS 12.0+
- Xcode 14.0+
- Swift 5.7+
- A running [Music Assistant Server](https://music-assistant.io/integration/installation/)

## Getting Started

### Prerequisites

You'll need a Music Assistant server running and accessible from your device. For installation instructions, visit:
- [Music Assistant Documentation](https://music-assistant.io/)
- [Server Installation Guide](https://music-assistant.io/integration/installation/)

### Building the App

1. Clone the repository:
   ```bash
   cd /path/to/MusicAssistant
   ```

2. Open the project in Xcode:
   ```bash
   open MusicAssistant.xcodeproj
   ```

3. Build and run the project (⌘R)

### First-Time Setup

1. Launch the app
2. Enter your Music Assistant server URL (e.g., `http://192.168.1.100:8095`)
3. Sign in with your credentials
4. Start browsing and playing your music!

## Architecture

### Core Components

- **AppModel** - Central state management for the application
  - Connection state management
  - Player synchronization
  - Queue management
  - Background/foreground handling

- **MusicAssistantAPI** - REST API client for Music Assistant server
  - Authentication
  - Music library operations
  - Player control
  - Provider and configuration management

- **LocalPlaybackManager** - AVFoundation-based local audio playback
  - Streaming audio playback
  - Playback state management
  - Now Playing integration

- **Models** - Comprehensive data models for Music Assistant entities
  - Players, Queues, and Queue Items
  - Tracks, Albums, Artists, Playlists
  - Radio Stations and Audiobooks
  - Provider and Player Configuration

### Views

- **MainTabView** - Primary navigation interface
- **PlayersView** - View and control available players
- **LibraryView** - Browse your music library by category
- **BrowseView** - Navigate music provider hierarchies
- **SearchView** - Search across all music sources
- **NowPlayingView** - Full-screen now playing interface
- **SettingsView** - App configuration and provider management
- **LoginView** - Server connection and authentication

## Features in Detail

### Local Device Playback

The app can act as a Music Assistant player itself, streaming audio directly to your iOS/macOS device using AVFoundation. This allows you to:
- Use your device as a standalone player
- Control playback with standard media controls
- See Now Playing information in Control Center
- Maintain playback state across app restarts

### Multi-Player Management

- View all available players on your network
- Group players together for synchronized playback
- Control volume for individual players or groups
- View real-time playback state

### Provider Integration

Connect to various music providers:
- Streaming services (Spotify, Tidal, Qobuz, etc.)
- Local music libraries
- Radio stations
- Audiobook services

### Library Browsing

Organize and browse your music by:
- Artists
- Albums
- Tracks
- Playlists
- Radio Stations
- Audiobooks

## API Integration

The app communicates with the Music Assistant server using its REST API and WebSocket connections for real-time updates. Key API operations include:

- **Authentication**: Provider-based login with token management
- **Player Control**: Play, pause, skip, shuffle, repeat
- **Queue Management**: View and modify playback queues
- **Library Access**: Browse and search music collections
- **Configuration**: Manage providers and player settings

## Development

### Project Structure

```
MusicAssistant/
├── MusicAssistant/
│   ├── Components/           # Reusable UI components
│   ├── Assets.xcassets/      # App icons and images
│   ├── Models.swift          # Data models
│   ├── MusicAssistantAPI.swift  # API client
│   ├── AppModel.swift        # App state management
│   ├── LocalPlaybackManager.swift  # Audio playback
│   ├── Views/                # SwiftUI views
│   └── ...
├── MusicAssistantTests/      # Unit tests
└── MusicAssistantUITests/    # UI tests
```

### Key Technologies

- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming for state management
- **AVFoundation** - Audio playback
- **URLSession** - Network requests
- **Keychain** - Secure credential storage

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Related Projects

- [Music Assistant Server](https://github.com/music-assistant/server) - The backend server
- [Music Assistant Frontend](../frontend) - Vue-based web frontend

## License

This project is part of the Music Assistant ecosystem.

## Acknowledgments

- Built for the [Music Assistant](https://music-assistant.io/) project
- Part of the [Open Home Foundation](https://www.openhomefoundation.org/)

---

[![A project from the Open Home Foundation](https://www.openhomefoundation.org/badges/ohf-project.png)](https://www.openhomefoundation.org/)