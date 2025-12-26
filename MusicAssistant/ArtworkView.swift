import Foundation
import SwiftUI

struct ArtworkView: View {
    let urlString: String?
    var baseURL: URL? = nil
    var cornerRadius: CGFloat = 12
    var placeholderIcon: String = "music.note"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray4),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        PlaceholderView(icon: placeholderIcon)
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.8)
                    @unknown default:
                        PlaceholderView(icon: placeholderIcon)
                    }
                }
            } else {
                PlaceholderView(icon: placeholderIcon)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var resolvedURL: URL? {
        guard let urlString, !urlString.isEmpty else { return nil }

        // Handle various URL formats
        let cleanedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // If it's already a full URL with scheme
        if let url = URL(string: cleanedString), url.scheme != nil {
            return url
        }

        // If we have a base URL, try to construct the full URL
        if let baseURL {
            // Remove leading slashes for proper path appending
            let pathComponent = cleanedString.trimmingCharacters(
                in: CharacterSet(charactersIn: "/"))

            // Try different URL construction methods
            if let url = URL(string: pathComponent, relativeTo: baseURL) {
                return url.absoluteURL
            }

            // Fallback: manually construct the URL
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
            if components?.path.hasSuffix("/") == false {
                components?.path += "/"
            }
            components?.path += pathComponent

            if let url = components?.url {
                return url
            }

            // Last resort: simple string concatenation
            let baseString = baseURL.absoluteString.trimmingCharacters(
                in: CharacterSet(charactersIn: "/"))
            return URL(string: "\(baseString)/\(pathComponent)")
        }

        // Try to create URL directly as last resort
        return URL(string: cleanedString)
    }
}

// MARK: - Placeholder View

private struct PlaceholderView: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.title)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // With image
        ArtworkView(
            urlString: "https://example.com/image.jpg",
            cornerRadius: 12
        )
        .frame(width: 150, height: 150)

        // Without image (placeholder)
        ArtworkView(
            urlString: nil,
            cornerRadius: 12
        )
        .frame(width: 150, height: 150)

        // Circular (for artists)
        ArtworkView(
            urlString: nil,
            cornerRadius: 75,
            placeholderIcon: "person.fill"
        )
        .frame(width: 150, height: 150)
        .clipShape(Circle())
    }
    .padding()
}
