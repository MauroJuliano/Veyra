import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioMessageRecorder: NSObject, AVAudioRecorderDelegate {
    struct Recording: Sendable {
        let data: Data
        let duration: TimeInterval
    }

    private(set) var isRecording = false
    private(set) var duration: TimeInterval = 0
    private(set) var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?
    private var startedAt: Date?
    private var fileURL: URL?

    func start() async {
        guard !isRecording else { return }
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard allowed else {
            errorMessage = String(localized: "Microphone access is required to record audio messages.")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("veyra-audio-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.prepareToRecord()
            guard recorder.record() else { throw AudioMessageError.couldNotStart }

            self.recorder = recorder
            fileURL = url
            startedAt = .now
            duration = 0
            errorMessage = nil
            isRecording = true
            startDurationUpdates()
        } catch {
            errorMessage = error.localizedDescription
            cancel()
        }
    }

    func finish() throws -> Recording {
        guard let recorder, let fileURL else { throw AudioMessageError.noRecording }
        let recordedDuration = max(recorder.currentTime, duration)
        recorder.stop()
        stopTracking()
        let data = try Data(contentsOf: fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        reset()
        return Recording(data: data, duration: recordedDuration)
    }

    func cancel() {
        recorder?.stop()
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        stopTracking()
        reset()
    }

    private func startDurationUpdates() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let startedAt = self.startedAt else { return }
                self.duration = Date.now.timeIntervalSince(startedAt)
            }
        }
    }

    private func stopTracking() {
        meterTask?.cancel()
        meterTask = nil
    }

    private func reset() {
        recorder = nil
        fileURL = nil
        startedAt = nil
        duration = 0
        isRecording = false
    }
}

private enum AudioMessageError: LocalizedError {
    case couldNotStart
    case noRecording

    var errorDescription: String? {
        switch self {
        case .couldNotStart: String(localized: "Audio recording could not be started.")
        case .noRecording: String(localized: "No audio recording is available.")
        }
    }
}
