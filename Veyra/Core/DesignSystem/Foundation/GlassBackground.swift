import SwiftUI

struct GlassBackground: View {
    var cornerRadius: CGFloat = 18
    var tintOpacity: Double = 0.12
    var glowOpacity: Double = 0.16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                VeyraColor.accent.opacity(tintOpacity * 1.35),
                                Color.purple.opacity(tintOpacity),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: VeyraColor.accent.opacity(glowOpacity), radius: 14, y: 5)
    }
}

struct VeyraSkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var showsAvatar = true
    var lineCount = 2
    @State private var highlightOffset: CGFloat = -1

    var body: some View {
        HStack(spacing: VeyraSpacing.md) {
            if showsAvatar {
                Circle()
                    .fill(VeyraColor.surfaceElevated)
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: VeyraSpacing.sm) {
                skeletonLine(width: 0.58)
                if lineCount > 1 { skeletonLine(width: 0.82) }
            }
        }
        .padding(VeyraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { GlassBackground(glowOpacity: 0.06) }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if !reduceMotion {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.13), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.55)
                    .offset(x: proxy.size.width * highlightOffset)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                highlightOffset = 1.2
            }
        }
    }

    private func skeletonLine(width: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(VeyraColor.surfaceElevated)
                .frame(width: proxy.size.width * width, height: 12)
        }
        .frame(height: 12)
    }
}

struct VeyraImagePlaceholder: View {
    var body: some View {
        ZStack {
            VeyraColor.surfaceElevated
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(VeyraColor.textSecondary)
        }
        .accessibilityHidden(true)
    }
}
