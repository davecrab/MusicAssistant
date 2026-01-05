import Combine
import SwiftUI
import WebKit

/// A view that uses WebKit to authenticate with Apple Music and extract the media-user-token cookie
struct AppleMusicWebAuthView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var loadingProgress: Double = 0
    @State private var extractedToken: String?
    @State private var errorMessage: String?
    @State private var showSuccessAnimation = false

    /// Callback when token is successfully extracted
    var onTokenExtracted: ((String) -> Void)?

    /// Callback when user cancels or dismissal occurs
    var onCancel: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                // WebView
                AppleMusicWebView(
                    isLoading: $isLoading,
                    loadingProgress: $loadingProgress,
                    extractedToken: $extractedToken,
                    errorMessage: $errorMessage
                )

                // Loading overlay
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView(value: loadingProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                        Text("Loading Apple Music...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Success overlay
                if showSuccessAnimation {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                        Text("Token Extracted!")
                            .font(.headline)
                        Text("Your Apple Music token has been captured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle("Sign in to Apple Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel?()
                        dismiss()
                    }
                }

                if extractedToken != nil && !showSuccessAnimation {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use Token") {
                            if let token = extractedToken {
                                onTokenExtracted?(token)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .alert(
                "Error",
                isPresented: .init(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .onChange(of: extractedToken) { _, newToken in
                if newToken != nil {
                    withAnimation(.spring(duration: 0.5)) {
                        showSuccessAnimation = true
                    }

                    // Auto-dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if let token = newToken {
                            onTokenExtracted?(token)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - WebView Wrapper

/// UIViewRepresentable wrapper for WKWebView that monitors for the media-user-token cookie
struct AppleMusicWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var loadingProgress: Double
    @Binding var extractedToken: String?
    @Binding var errorMessage: String?

    private let appleMusicURL = URL(string: "https://music.apple.com/login")!
    private let tokenCookieName = "media-user-token"

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Enable JavaScript
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // Set up data store for cookie access
        let dataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = dataStore

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Add progress observer
        context.coordinator.progressObservation = webView.observe(\.estimatedProgress) {
            webView, _ in
            DispatchQueue.main.async {
                self.loadingProgress = webView.estimatedProgress
            }
        }

        // Start cookie monitoring
        context.coordinator.startCookieMonitoring(for: webView)

        // Load Apple Music
        let request = URLRequest(url: appleMusicURL)
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: AppleMusicWebView
        var progressObservation: NSKeyValueObservation?
        var cookieTimer: Timer?
        weak var webView: WKWebView?

        init(_ parent: AppleMusicWebView) {
            self.parent = parent
        }

        deinit {
            cookieTimer?.invalidate()
            progressObservation?.invalidate()
        }

        func startCookieMonitoring(for webView: WKWebView) {
            self.webView = webView

            // Check cookies periodically
            cookieTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
                [weak self] _ in
                self?.checkForToken()
            }
        }

        func checkForToken() {
            guard let webView = webView, parent.extractedToken == nil else { return }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies {
                [weak self] cookies in
                guard let self = self else { return }

                // Look for the media-user-token cookie
                for cookie in cookies {
                    if cookie.name == self.parent.tokenCookieName && !cookie.value.isEmpty {
                        // Verify it's from Apple Music domain
                        if cookie.domain.contains("apple.com")
                            || cookie.domain.contains("music.apple.com")
                        {
                            DispatchQueue.main.async {
                                self.parent.extractedToken = cookie.value
                                self.cookieTimer?.invalidate()
                            }
                            return
                        }
                    }
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)
        {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }

            // Check for token immediately after page load
            checkForToken()
        }

        func webView(
            _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
        ) {
            handleError(error)
        }

        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            // Ignore cancelled errors (user navigation)
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }
            handleError(error)
        }

        private func handleError(_ error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.errorMessage = error.localizedDescription
            }
        }

        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow all navigation within Apple domains
            if let url = navigationAction.request.url {
                let host = url.host ?? ""
                if host.contains("apple.com") || host.contains("icloud.com") || host.isEmpty {
                    decisionHandler(.allow)
                    return
                }
            }

            // Allow the initial request and any Apple-related URLs
            decisionHandler(.allow)
        }
    }
}

// MARK: - Token Extractor Utility

/// Utility class for extracting Apple Music tokens
@MainActor
class AppleMusicTokenExtractor: ObservableObject {
    static let shared = AppleMusicTokenExtractor()

    @Published var isExtracting = false
    @Published var extractedToken: String?
    @Published var lastError: String?

    private init() {}

    /// Check if we already have a cached token in the web view cookie store
    func checkExistingToken() async -> String? {
        return await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                for cookie in cookies {
                    if cookie.name == "media-user-token" && !cookie.value.isEmpty {
                        if cookie.domain.contains("apple.com") {
                            continuation.resume(returning: cookie.value)
                            return
                        }
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }

    /// Clear any cached Apple Music cookies (useful for re-authentication)
    func clearAppleMusicCookies() async {
        let dataStore = WKWebsiteDataStore.default()
        let cookies = await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }

        for cookie in cookies {
            if cookie.domain.contains("apple.com") || cookie.domain.contains("music.apple.com") {
                await dataStore.httpCookieStore.deleteCookie(cookie)
            }
        }
    }

    func reset() {
        isExtracting = false
        extractedToken = nil
        lastError = nil
    }
}

// MARK: - Compact Button View for Quick Access

/// A compact view that can be embedded in forms to trigger Apple Music web auth
struct AppleMusicWebAuthButton: View {
    @State private var showWebAuth = false
    var onTokenExtracted: ((String) -> Void)?

    var body: some View {
        Button {
            showWebAuth = true
        } label: {
            Label("Sign in to Apple Music", systemImage: "globe")
        }
        .sheet(isPresented: $showWebAuth) {
            AppleMusicWebAuthView(
                onTokenExtracted: { token in
                    onTokenExtracted?(token)
                },
                onCancel: {
                    showWebAuth = false
                }
            )
        }
    }
}

// MARK: - Preview

#Preview("Web Auth View") {
    AppleMusicWebAuthView { token in
        print("Got token: \(token.prefix(50))...")
    }
}

#Preview("Auth Button") {
    Form {
        Section {
            AppleMusicWebAuthButton { token in
                print("Token extracted: \(token.prefix(50))...")
            }
        }
    }
}
