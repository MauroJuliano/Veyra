import SwiftUI
import CryptoKit
import UIKit

enum VeyraAvatarSize {
    case small
    case medium
    case large
    case xLarge

    var dimension: CGFloat {
        switch self {
        case .small: 32
        case .medium: 44
        case .large: 64
        case .xLarge: 88
        }
    }

    var font: Font {
        switch self {
        case .small: VeyraTypography.caption
        case .medium: VeyraTypography.bodyEmphasized
        case .large, .xLarge: VeyraTypography.title
        }
    }
}

enum AvatarInitials {
    static func make(from name: String) -> String {
        let words = name
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(2)

        return words
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

struct VeyraAvatar: View {
    let name: String
    var image: Image?
    var imageURL: URL?
    var size: VeyraAvatarSize = .medium
    var showsOnlineIndicator = false

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else if let imageURL {
                VeyraCachedImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView().tint(VeyraColor.accent)
                }
            } else {
                Text(AvatarInitials.make(from: name))
                    .font(size.font)
                    .foregroundStyle(VeyraColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VeyraColor.accentMuted)
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            if showsOnlineIndicator {
                Circle()
                    .fill(VeyraColor.success)
                    .frame(width: size.dimension * 0.28, height: size.dimension * 0.28)
                    .overlay(Circle().stroke(VeyraColor.surface, lineWidth: 2))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(name)
    }
}

struct VeyraCachedImage<Content: View, Placeholder: View>: View {
    let url: URL
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let loadedImage {
                content(Image(uiImage: loadedImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            loadedImage = nil
            guard let data = try? await VeyraImagePipeline.shared.data(for: url),
                  let image = UIImage(data: data) else { return }
            loadedImage = image
        }
    }
}

actor VeyraImagePipeline {
    static let shared = VeyraImagePipeline()

    private let memoryCache = NSCache<NSString, NSData>()
    private let cacheDirectory: URL
    private var runningTasks: [String: Task<Data, Error>] = [:]

    private init() {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = root.appendingPathComponent("VeyraImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        memoryCache.totalCostLimit = 48 * 1_024 * 1_024
    }

    func data(for url: URL) async throws -> Data {
        let key = Self.cacheKey(for: url)
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached as Data
        }

        let fileURL = cacheDirectory.appendingPathComponent(key)
        if let diskData = try? Data(contentsOf: fileURL) {
            memoryCache.setObject(diskData as NSData, forKey: key as NSString, cost: diskData.count)
            return diskData
        }

        if let runningTask = runningTasks[key] {
            return try await runningTask.value
        }

        let task = Task<Data, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                throw VeyraImagePipelineError.invalidResponse
            }
            guard UIImage(data: data) != nil else {
                throw VeyraImagePipelineError.invalidImage
            }
            return data
        }
        runningTasks[key] = task

        do {
            let data = try await task.value
            try? data.write(to: fileURL, options: .atomic)
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            runningTasks[key] = nil
            return data
        } catch {
            runningTasks[key] = nil
            throw error
        }
    }

    static func cacheKey(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        let stableURL = components?.url?.absoluteString ?? url.absoluteString
        return SHA256.hash(data: Data(stableURL.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

enum VeyraImagePipelineError: Error {
    case invalidResponse
    case invalidImage
}

#Preview("Avatar sizes") {
    HStack(spacing: VeyraSpacing.md) {
        VeyraAvatar(name: "Mauro Figueiredo", size: .small)
        VeyraAvatar(name: "Mauro Figueiredo", size: .medium)
        VeyraAvatar(name: "Mauro Figueiredo", size: .large)
    }
    .padding()
    .background(VeyraColor.background)
}
