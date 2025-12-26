import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum DefaultsKey {
        static let serverURL = "server_url"
    }

    private let keychain = Keychain(service: "crabtree.MusicAssistant")

    @Published var serverURLString: String {
        didSet { UserDefaults.standard.set(serverURLString, forKey: DefaultsKey.serverURL) }
    }

    var serverURL: URL? {
        let trimmed = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    var token: String? {
        get { keychain.getString(forKey: "access_token") }
        set {
            if let newValue, !newValue.isEmpty {
                keychain.setString(newValue, forKey: "access_token")
            } else {
                keychain.delete(forKey: "access_token")
            }
            objectWillChange.send()
        }
    }

    init() {
        serverURLString = UserDefaults.standard.string(forKey: DefaultsKey.serverURL) ?? "http://192.168.4.19:8095"
    }
}
