import AVFoundation
import SwiftUI

struct AudioMessagePlayerView: View {
    let url: URL
    let duration: TimeInterval
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var progress = 0.0
    @State private var isPreparing = true

    var body: some View {
        HStack(spacing: VeyraSpacing.sm) {
            Button(action: togglePlayback) {
                Group {
                    if isPreparing { ProgressView().controlSize(.small) }
                    else { Image(systemName: isPlaying ? "pause.fill" : "play.fill") }
                }
                    .frame(width: 34, height: 34)
                    .background(VeyraColor.accent.opacity(0.22))
                    .clipShape(Circle())
            }
            .disabled(isPreparing)
            .accessibilityLabel(isPlaying ? "Pause audio" : "Play audio")

            VStack(alignment: .leading, spacing: 5) {
                ProgressView(value: progress)
                    .tint(VeyraColor.accent)
                Text(formattedDuration)
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.textSecondary)
            }
        }
        .frame(width: 210)
        .padding(.horizontal, VeyraSpacing.md)
        .padding(.vertical, VeyraSpacing.sm)
        .task(id: isPlaying) {
            guard isPlaying else { return }
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(for: .milliseconds(100))
                guard let player else { return }
                let seconds = player.currentTime().seconds
                guard seconds.isFinite else { continue }
                progress = min(max(seconds / max(duration, 0.1), 0), 1)
                if progress >= 0.999 {
                    await player.seek(to: .zero)
                    progress = 0
                    isPlaying = false
                }
            }
        }
        .task {
            guard player == nil else { return }
            if let playableURL = try? await AudioMessageCache.shared.localURL(for: url) {
                player = AVPlayer(url: playableURL)
            } else {
                player = AVPlayer(url: url)
            }
            isPreparing = false
        }
        .onDisappear { player?.pause() }
    }

    private var formattedDuration: String {
        let value = Int(duration.rounded())
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    private func togglePlayback() {
        if player == nil { player = AVPlayer(url: url) }
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            if progress >= 0.999 { Task { await player.seek(to: .zero) } }
            player.play()
        }
        isPlaying.toggle()
    }
}

private actor AudioMessageCache {
    static let shared = AudioMessageCache()

    func localURL(for remoteURL: URL) async throws -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VeyraAudio", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = remoteURL.lastPathComponent.isEmpty ? "\(UUID().uuidString).m4a" : remoteURL.lastPathComponent
        let localURL = directory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: localURL.path) { return localURL }
        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        try data.write(to: localURL, options: .atomic)
        return localURL
    }
}
