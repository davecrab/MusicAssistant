import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        Group {
            if appModel.isSignedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .tint(.pink)
        .task {
            if appModel.settings.serverURL != nil {
                await appModel.loadAuthProviders()
            }
        }
        .onChange(of: appModel.lastError) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showingError = true
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                appModel.lastError = nil
            }
        } message: {
            Text(errorMessage)
        }
    }
}
