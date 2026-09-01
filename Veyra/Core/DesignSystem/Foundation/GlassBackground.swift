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
