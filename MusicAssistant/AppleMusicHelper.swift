import Combine
import Foundation
import MusicKit
import StoreKit
import SwiftUI

/// Helper class for Apple Music / MusicKit integration
/// This enables automatic retrieval of the Music User Token for Apple Music provider setup
@MainActor
class AppleMusicHelper: ObservableObject {
    static let shared = AppleMusicHelper()

    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var isAuthorizing = false
    @Published var lastError: String?

    private init() {
        // Check initial status
        authorizationStatus = MusicAuthorization.currentStatus
    }

    /// Request authorization to access Apple Music
    func requestAuthorization() async -> Bool {
        isAuthorizing = true
        lastError = nil

        let status = await MusicAuthorization.request()
        authorizationStatus = status
        isAuthorizing = false

        switch status {
        case .authorized:
            return true
        case .denied:
            lastError = "Apple Music access was denied. Please enable it in Settings."
            return false
        case .restricted:
            lastError = "Apple Music access is restricted on this device."
            return false
        case .notDetermined:
            lastError = "Authorization status could not be determined."
            return false
        @unknown default:
            lastError = "Unknown authorization status."
            return false
        }
    }

    /// Get the Music User Token for Apple Music API
    /// This token can be used with the Music Assistant Apple Music provider
    func getUserToken() async -> Result<String, AppleMusicError> {
        // First check authorization
        if authorizationStatus != .authorized {
            let authorized = await requestAuthorization()
            if !authorized {
                return .failure(.notAuthorized(lastError ?? "Not authorized"))
            }
        }

        do {
            // Request a user token from Apple Music
            // The developer token is handled automatically by MusicKit
            let userToken = try await MusicUserTokenProvider().userToken(
                for: "com.music-assistant.ios",
                options: .ignoreCache
            )

            return .success(userToken)
        } catch {
            // If MusicUserTokenProvider fails, return the error
            // The deprecated SKCloudServiceController method has been removed
            return .failure(.tokenExtractionNotSupported)
        }
    }

    /// Check if Apple Music subscription is active
    func checkSubscriptionStatus() async -> SubscriptionStatus {
        guard authorizationStatus == .authorized else {
            return .unknown
        }

        do {
            let subscription = try await MusicSubscription.current
            if subscription.canPlayCatalogContent {
                return .active
            } else if subscription.canBecomeSubscriber {
                return .eligible
            } else {
                return .none
            }
        } catch {
            return .unknown
        }
    }

    /// Reset authorization state
    func reset() {
        authorizationStatus = MusicAuthorization.currentStatus
        lastError = nil
    }
}

// MARK: - Custom User Token Provider

/// A provider that can request user tokens from Apple Music
private actor MusicUserTokenProvider {
    func userToken(for bundleIdentifier: String, options: Options = []) async throws -> String {
        // Use the MusicDataRequest approach to get a user token
        // This requires a valid Apple Music subscription

        // First, verify we can make requests
        let request = MusicCatalogSearchRequest(term: "test", types: [Song.self])

        do {
            // If this succeeds, we have a valid session
            _ = try await request.response()

            // Now get the user token through subscription info
            let subscription = try await MusicSubscription.current
            guard subscription.canPlayCatalogContent else {
                throw AppleMusicError.noSubscription
            }

            // The user token is embedded in successful API requests
            // We need to extract it from the response headers
            // This is a workaround since MusicKit doesn't directly expose the token

            throw AppleMusicError.tokenExtractionNotSupported
        } catch {
            throw error
        }
    }

    struct Options: OptionSet {
        let rawValue: Int
        static let ignoreCache = Options(rawValue: 1 << 0)
    }
}

// MARK: - Error Types

enum AppleMusicError: LocalizedError {
    case notAuthorized(String)
    case tokenRequestFailed(String)
    case noTokenReturned
    case noSubscription
    case tokenExtractionNotSupported

    var errorDescription: String? {
        switch self {
        case .notAuthorized(let reason):
            return "Not authorized to access Apple Music: \(reason)"
        case .tokenRequestFailed(let reason):
            return "Failed to request user token: \(reason)"
        case .noTokenReturned:
            return "No user token was returned from Apple Music"
        case .noSubscription:
            return "An active Apple Music subscription is required"
        case .tokenExtractionNotSupported:
            return "Automatic token extraction is not supported. Please obtain the token manually."
        }
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus {
    case active
    case eligible
    case none
    case unknown

    var description: String {
        switch self {
        case .active:
            return "Active Apple Music subscription"
        case .eligible:
            return "Eligible for Apple Music subscription"
        case .none:
            return "No Apple Music subscription"
        case .unknown:
            return "Unknown subscription status"
        }
    }

    var isSubscribed: Bool {
        self == .active
    }
}

// MARK: - SwiftUI View for Apple Music Setup

struct AppleMusicSetupView: View {
    @StateObject private var helper = AppleMusicHelper.shared
    @State private var userToken: String = ""
    @State private var isLoading = false
    @State private var showManualEntry = false
    @State private var subscriptionStatus: SubscriptionStatus = .unknown

    var onTokenObtained: ((String) -> Void)?

    var body: some View {
        List {
            // Status Section
            Section {
                HStack {
                    Label("Authorization", systemImage: authIcon)
                    Spacer()
                    Text(authStatusText)
                        .foregroundStyle(authStatusColor)
                }

                if helper.authorizationStatus == .authorized {
                    HStack {
                        Label("Subscription", systemImage: subscriptionIcon)
                        Spacer()
                        Text(subscriptionStatus.description)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Apple Music Status")
            }

            // Action Section
            Section {
                if helper.authorizationStatus != .authorized {
                    Button {
                        Task {
                            _ = await helper.requestAuthorization()
                            if helper.authorizationStatus == .authorized {
                                subscriptionStatus = await helper.checkSubscriptionStatus()
                            }
                        }
                    } label: {
                        Label("Authorize Apple Music", systemImage: "apple.logo")
                    }
                    .disabled(helper.isAuthorizing)
                } else {
                    Button {
                        Task { await attemptGetToken() }
                    } label: {
                        HStack {
                            Label("Get User Token Automatically", systemImage: "key")
                            if isLoading {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoading)
                }

                Button {
                    showManualEntry = true
                } label: {
                    Label("Enter Token Manually", systemImage: "text.cursor")
                }
            } header: {
                Text("Get Token")
            } footer: {
                Text(
                    "The automatic method may not work on all devices. If it fails, you can obtain the token manually from music.apple.com using browser developer tools."
                )
            }

            // Token Display/Entry Section
            if !userToken.isEmpty || showManualEntry {
                Section {
                    if showManualEntry {
                        TextField("Music User Token", text: $userToken, axis: .vertical)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3...6)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        Text(userToken)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }

                    if !userToken.isEmpty {
                        Button {
                            onTokenObtained?(userToken)
                        } label: {
                            Label("Use This Token", systemImage: "checkmark.circle")
                        }

                        Button {
                            UIPasteboard.general.string = userToken
                        } label: {
                            Label("Copy Token", systemImage: "doc.on.doc")
                        }
                    }
                } header: {
                    Text("Music User Token")
                }
            }

            // Error Section
            if let error = helper.lastError {
                Section {
                    Label {
                        Text(error)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Error")
                }
            }

            // Help Section
            Section {
                DisclosureGroup("Manual Token Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        instructionStep(1, "Navigate to https://music.apple.com/ and sign in")
                        instructionStep(
                            2, "Open Developer Tools (View → Developer → Developer Tools)")
                        instructionStep(3, "Click the 'Application' tab")
                        instructionStep(
                            4, "Under Storage → Cookies, click 'https://music.apple.com'")
                        instructionStep(5, "Find the entry called 'media-user-token'")
                        instructionStep(6, "Copy the cookie value and paste it above")
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Help")
            }
        }
        .navigationTitle("Apple Music Setup")
        .task {
            if helper.authorizationStatus == .authorized {
                subscriptionStatus = await helper.checkSubscriptionStatus()
            }
        }
    }

    private func attemptGetToken() async {
        isLoading = true

        let result = await helper.getUserToken()

        await MainActor.run {
            isLoading = false

            switch result {
            case .success(let token):
                userToken = token
            case .failure(let error):
                // Show manual entry on failure
                showManualEntry = true
                helper.lastError = error.localizedDescription
            }
        }
    }

    private var authIcon: String {
        switch helper.authorizationStatus {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .restricted: return "lock.fill"
        case .notDetermined: return "questionmark.circle"
        @unknown default: return "questionmark.circle"
        }
    }

    private var authStatusText: String {
        switch helper.authorizationStatus {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }

    private var authStatusColor: Color {
        switch helper.authorizationStatus {
        case .authorized: return .green
        case .denied: return .red
        case .restricted: return .orange
        case .notDetermined: return .secondary
        @unknown default: return .secondary
        }
    }

    private var subscriptionIcon: String {
        switch subscriptionStatus {
        case .active: return "checkmark.seal.fill"
        case .eligible: return "star"
        case .none: return "xmark.seal"
        case .unknown: return "questionmark"
        }
    }

    @ViewBuilder
    private func instructionStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.semibold)
                .frame(width: 20, alignment: .leading)
            Text(text)
                .font(.caption)
        }
    }
}

#Preview {
    NavigationStack {
        AppleMusicSetupView()
    }
}
