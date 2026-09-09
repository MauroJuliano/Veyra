import AVFoundation
import SwiftUI

struct AudioMessagePlayerView: View {
    let url: URL
    let duration: TimeInterval
    let avatarName: String?
    let avatarURL: URL?
    let avatarSize: VeyraAvatarSize
    let showsOnlineIndicator: Bool
    let direction: Message.Direction
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var progress = 0.0
    @State private var isPreparing = true
    @State private var waveformSamples = AudioWaveformSamples.placeholder
    
    init(
        url: URL,
        duration: TimeInterval,
        avatarName: String? = nil,
        avatarURL: URL? = nil,
        avatarSize: VeyraAvatarSize = .medium,
        showsOnlineIndicator: Bool = false,
        direction: Message.Direction = .incoming
    ) {
        self.url = url
        self.duration = duration
        self.avatarName = avatarName
        self.avatarURL = avatarURL
        self.avatarSize = avatarSize
        self.showsOnlineIndicator = showsOnlineIndicator
        self.direction = direction
    }
    
    var isOutgoing: Bool { direction == .outgoing }
    var hasAvatar: Bool { avatarName != nil }
    
    var body: some View {
        HStack(alignment: .center, spacing: VeyraSpacing.sm) {
            if let name = avatarName {
                VeyraAvatar(
                    name: name,
                    imageURL: avatarURL,
                    size: .large,
                    showsOnlineIndicator: showsOnlineIndicator
                )
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(action: togglePlayback) {
                        Group {
                            if isPreparing { ProgressView().controlSize(.small) }
                            else { Image(systemName: isPlaying ? "pause.fill" : "play.fill") }
                        }
                        .frame(width: 44, height: 44)
                    }
                    .disabled(isPreparing)
                    .accessibilityLabel(isPlaying ? "Pause audio" : "Play audio")
                    .accessibilityValue(formattedDuration)
                    
                    
                    AudioWaveformView(samples: waveformSamples, progress: progress, onSeek: seek)
                }
                
                Text(formattedDuration)
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.textSecondary)
                    .padding(.leading, 44 + VeyraSpacing.sm)
                
            }
        }
        .frame(width: hasAvatar ? 270 : 210)
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
                waveformSamples = await AudioWaveformSampler.shared.samples(for: playableURL)
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
    
    private func seek(to value: Double) {
        let value = min(max(value, 0), 1)
        progress = value
        let time = CMTime(seconds: duration * value, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
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

#Preview("Audio message player") {
    AudioMessagePlayerView(
        url: URL(fileURLWithPath: "/tmp/veyra-audio-preview.m4a"),
        duration: 42,
        avatarName: "Martha Nielsen",
        avatarSize: .medium,
        showsOnlineIndicator: true,
        direction: .incoming
    )
    .padding()
    .background(VeyraColor.background)
    .preferredColorScheme(.dark)
}
