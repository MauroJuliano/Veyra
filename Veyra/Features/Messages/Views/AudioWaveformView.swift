import SwiftUI

struct AudioWaveformView: View {
    let samples: [CGFloat]
    let progress: Double
    var onSeek: (Double) -> Void = { _ in }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                waveform(color: VeyraColor.textSecondary.opacity(0.35), height: proxy.size.height)
                waveform(color: VeyraColor.accent, height: proxy.size.height)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: proxy.size.width * clampedProgress)
                    }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard proxy.size.width > 0 else { return }
                        onSeek(min(max(value.location.x / proxy.size.width, 0), 1))
                    }
            )
        }
        .frame(height: 34)
        .accessibilityElement()
        .accessibilityLabel("Audio progress")
        .accessibilityValue(Text("\(Int(clampedProgress * 100))%"))
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            switch direction {
            case .increment: onSeek(min(clampedProgress + step, 1))
            case .decrement: onSeek(max(clampedProgress - step, 0))
            @unknown default: break
            }
        }
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private func waveform(color: Color, height: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                Capsule()
                    .fill(color)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(3, min(sample, 1) * height))
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

#Preview("Audio waveform") {
    AudioWaveformView(
        samples: AudioWaveformSamples.placeholder,
        progress: 0.38
    )
    .frame(width: 180)
    .padding()
    .background(VeyraColor.background)
    .preferredColorScheme(.dark)
}
