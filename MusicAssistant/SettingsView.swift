import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

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
                }

                Section("Session") {
                    if appModel.isSignedIn {
                        Button("Sign Out", role: .destructive) { appModel.signOut() }
                    }
                }

                Section("Debug") {
                    if let queue = appModel.activeQueue {
                        LabeledContent("Queue", value: queue.queueID)
                        LabeledContent("State", value: queue.state.rawValue)
                    }
                    LabeledContent("Players", value: "\(appModel.players.count)")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
