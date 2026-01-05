import Combine
import SwiftUI

/// A banner view that shows connection status to the Music Assistant server
struct ConnectionBannerView: View {
    let connectionState: AppModel.ConnectionState

    @State private var dotCount = 0

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        if connectionState.showBanner {
            VStack(spacing: 0) {
                // Safe area background
                bannerColor
                    .frame(height: 0)
                    .background(bannerColor)
                    .ignoresSafeArea(edges: .top)

                // Banner content
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)

                    Text(animatedMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)

                    Spacer()

                    // Subtle icon indicator
                    Image(
                        systemName: connectionState == .connecting ? "wifi" : "wifi.exclamationmark"
                    )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(bannerColor)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 4
            }
        }
    }

    private var animatedMessage: String {
        let baseMessage =
            switch connectionState {
            case .connecting:
                "Connecting to server"
            case .reconnecting:
                "Reconnecting"
            default:
                connectionState.message.replacingOccurrences(of: "...", with: "")
            }
        let dots = String(repeating: ".", count: dotCount)
        return baseMessage + dots
    }

    private var bannerColor: Color {
        switch connectionState {
        case .connecting:
            return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .reconnecting:
            return Color.orange
        default:
            return .gray
        }
    }
}

/// A view modifier that adds the connection banner to any view
struct ConnectionBannerModifier: ViewModifier {
    @EnvironmentObject private var appModel: AppModel

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            ConnectionBannerView(connectionState: appModel.connectionState)
                .animation(.easeInOut(duration: 0.3), value: appModel.connectionState)
        }
    }
}

extension View {
    /// Adds a connection status banner that appears when connecting or reconnecting to the server
    func connectionBanner() -> some View {
        modifier(ConnectionBannerModifier())
    }
}

// MARK: - Previews

#Preview("Connecting") {
    ZStack(alignment: .top) {
        VStack {
            Text("Main Content")
                .padding(.top, 60)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))

        ConnectionBannerView(connectionState: .connecting)
    }
}

#Preview("Reconnecting") {
    ZStack(alignment: .top) {
        VStack {
            Text("Main Content")
                .padding(.top, 60)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))

        ConnectionBannerView(connectionState: .reconnecting)
    }
}

#Preview("Connected - No Banner") {
    ZStack(alignment: .top) {
        VStack {
            Text("Main Content")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))

        ConnectionBannerView(connectionState: .connected)
    }
}
