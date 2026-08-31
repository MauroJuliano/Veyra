import SwiftUI

enum VeyraAvatarSize {
    case small
    case medium
    case large

    var dimension: CGFloat {
        switch self {
        case .small: 32
        case .medium: 44
        case .large: 64
        }
    }

    var font: Font {
        switch self {
        case .small: VeyraTypography.caption
        case .medium: VeyraTypography.bodyEmphasized
        case .large: VeyraTypography.title
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
    var size: VeyraAvatarSize = .medium
    var showsOnlineIndicator = false

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
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

#Preview("Avatar sizes") {
    HStack(spacing: VeyraSpacing.md) {
        VeyraAvatar(name: "Mauro Figueiredo", size: .small)
        VeyraAvatar(name: "Mauro Figueiredo", size: .medium)
        VeyraAvatar(name: "Mauro Figueiredo", size: .large)
    }
    .padding()
    .background(VeyraColor.background)
}
