import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedProviderID: String = "builtin"
    @State private var username: String = ""
    @State private var password: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField(
                        "Server URL",
                        text: Binding(
                            get: { appModel.settings.serverURLString },
                            set: { appModel.settings.serverURLString = $0 }
                        )
                    )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Button("Load Providers") {
                        Task { await appModel.loadAuthProviders() }
                    }
                }

                Section("Login") {
                    Picker("Provider", selection: $selectedProviderID) {
                        ForEach(appModel.authProviders.isEmpty ? [AuthProvider(id: "builtin", name: "Built-in")] : appModel.authProviders) { provider in
                            Text(provider.name).tag(provider.id)
                        }
                    }

                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)

                    Button(appModel.isBusy ? "Signing In…" : "Sign In") {
                        Task { await appModel.signIn(providerID: selectedProviderID, username: username, password: password) }
                    }
                    .disabled(appModel.isBusy || appModel.settings.serverURL == nil || username.isEmpty || password.isEmpty)
                }

                Section {
                    Text("Tip: if you run a local server over plain HTTP, you’ll need an App Transport Security exception (configured in the project).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Music Assistant")
        }
    }
}
