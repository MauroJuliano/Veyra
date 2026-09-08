import AVFoundation
import Foundation

enum AudioWaveformSamples {
    static let placeholder: [CGFloat] = [
        0.16, 0.22, 0.30, 0.48, 0.72, 0.91, 0.76, 0.54, 0.31, 0.20,
        0.26, 0.42, 0.68, 0.86, 0.96, 0.82, 0.71, 0.60, 0.76, 0.88,
        0.79, 0.64, 0.55, 0.69, 0.84, 0.74, 0.59, 0.48, 0.61, 0.72,
        0.65, 0.50, 0.39, 0.30, 0.24, 0.18
    ]
}

actor AudioWaveformSampler {
    static let shared = AudioWaveformSampler()

    private var cache: [URL: [CGFloat]] = [:]

    func samples(for url: URL, count: Int = 36) -> [CGFloat] {
        if let cached = cache[url] { return cached }

        let samples = (try? extractSamples(from: url, count: count))
            ?? AudioWaveformSamples.placeholder
        cache[url] = samples
        return samples
    }

    private func extractSamples(from url: URL, count: Int) throws -> [CGFloat] {
        let file = try AVAudioFile(forReading: url)
        let totalFrames = max(file.length, 1)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: 4_096
        ) else {
            return AudioWaveformSamples.placeholder
        }

        var peaks = Array(repeating: Float.zero, count: count)
        var processedFrames: AVAudioFramePosition = 0

        while file.framePosition < file.length {
            try file.read(into: buffer)
            guard let channels = buffer.floatChannelData else { break }

            for frame in 0..<Int(buffer.frameLength) {
                let absoluteFrame = processedFrames + AVAudioFramePosition(frame)
                let bucket = min(Int(absoluteFrame * AVAudioFramePosition(count) / totalFrames), count - 1)
                var peak = Float.zero
                for channel in 0..<Int(buffer.format.channelCount) {
                    peak = max(peak, abs(channels[channel][frame]))
                }
                peaks[bucket] = max(peaks[bucket], peak)
            }
            processedFrames += AVAudioFramePosition(buffer.frameLength)
        }

        guard let maximum = peaks.max(), maximum > 0 else {
            return AudioWaveformSamples.placeholder
        }
        return peaks.map { max(0.08, CGFloat($0 / maximum)) }
    }
}
