import Combine
import Foundation
import SwiftUI
import WebKit

/// Helper class for Apple Music authentication
/// Uses WebKit-based authentication to extract the media-user-token cookie
@MainActor
class AppleMusicHelper: ObservableObject {
    static let shared = AppleMusicHelper()

    @Published var isAuthenticating = false
    @Published var lastError: String?
    @Published var hasExistingToken = false

    private init() {
        // Check for existing token on init
        Task {
            await checkForExistingToken()
        }
    }

    /// Check if there's an existing Apple Music token in the cookie store
    func checkForExistingToken() async {
        let token = await AppleMusicTokenExtractor.shared.checkExistingToken()
        hasExistingToken = token != nil
    }

    /// Get an existing token from the cookie store if available
    func getExistingToken() async -> String? {
        return await AppleMusicTokenExtractor.shared.checkExistingToken()
    }

    /// Clear any cached Apple Music cookies (for re-authentication)
    func clearCachedAuth() async {
        await AppleMusicTokenExtractor.shared.clearAppleMusicCookies()
        hasExistingToken = false
    }

    /// Reset helper state
    func reset() {
        isAuthenticating = false
        lastError = nil
    }
}

// MARK: - SwiftUI View for Apple Music Setup

struct AppleMusicSetupView: View {
    @StateObject private var helper = AppleMusicHelper.shared
    @State private var userToken: String = ""
    @State private var isLoading = false
    @State private var showWebAuth = false
    @State private var showManualEntry = false
    @State private var checkingExistingToken = true

    var onTokenObtained: ((String) -> Void)?

    var body: some View {
        List {
            // Status Section
            Section {
                if checkingExistingToken {
                    HStack {
                        Label("Checking for existing token...", systemImage: "magnifyingglass")
                        Spacer()
                        ProgressView()
                    }
                } else if helper.hasExistingToken {
                    HStack {
                        Label("Existing Token Found", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Use") {
                            Task { await useExistingToken() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                } else {
                    Label("No Token Found", systemImage: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Apple Music Status")
            }

            // Authentication Section
            Section {
                // Primary method: WebKit sign-in
                Button {
                    showWebAuth = true
                } label: {
                    HStack {
                        Label("Sign in to Apple Music", systemImage: "globe")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundStyle(.secondary)
                    }
                }

                // Secondary method: Manual entry
                Button {
                    showManualEntry.toggle()
                } label: {
                    Label(
                        showManualEntry ? "Hide Manual Entry" : "Enter Token Manually",
                        systemImage: "text.cursor"
                    )
                }

                // Re-authenticate option
                if helper.hasExistingToken {
                    Button(role: .destructive) {
                        Task {
                            await helper.clearCachedAuth()
                            userToken = ""
                        }
                    } label: {
                        Label("Clear Saved Token", systemImage: "trash")
                    }
                }
            } header: {
                Text("Get Token")
            } footer: {
                Text(
                    "Sign in to Apple Music using the web browser to automatically extract your token. Alternatively, you can enter a token manually."
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
        .sheet(isPresented: $showWebAuth) {
            AppleMusicWebAuthView(
                onTokenExtracted: { token in
                    userToken = token
                    showWebAuth = false
                    Task {
                        await helper.checkForExistingToken()
                    }
                },
                onCancel: {
                    showWebAuth = false
                }
            )
        }
        .task {
            checkingExistingToken = true
            await helper.checkForExistingToken()
            checkingExistingToken = false
        }
    }

    private func useExistingToken() async {
        if let token = await helper.getExistingToken() {
            userToken = token
            onTokenObtained?(token)
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
