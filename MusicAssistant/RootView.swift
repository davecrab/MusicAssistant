import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if appModel.isSignedIn {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .tint(.pink)

            // Connection banner overlay (only when signed in)
            if appModel.isSignedIn {
                ConnectionBannerView(connectionState: appModel.connectionState)
                    .animation(.easeInOut(duration: 0.3), value: appModel.connectionState)
            }
        }
        .task {
            if appModel.settings.serverURL != nil {
                await appModel.loadAuthProviders()
            }
        }
        .onChange(of: appModel.lastError) { _, newValue in
            if let error = newValue {
                // Only show error alert if we're connected (not during initial connection)
                if appModel.connectionState.isConnected {
                    errorMessage = error
                    showingError = true
                }
            }
        }
        .sheet(isPresented: $showingError) {
            ErrorSheetView(errorMessage: errorMessage) {
                appModel.lastError = nil
                showingError = false
            }
        }
    }
}

struct ErrorSheetView: View {
    let errorMessage: String
    let onDismiss: () -> Void
    @State private var showCopiedToast = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                ScrollView {
                    Text(errorMessage)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = errorMessage
                        showCopiedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedToast = false
                        }
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button("OK") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Error")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if showCopiedToast {
                    VStack {
                        Spacer()
                        Text("Copied to clipboard")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.bottom, 100)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut, value: showCopiedToast)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
