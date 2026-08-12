import Foundation
import AVFoundation

/// 마이크 권한 요청과 녹음(시작/중지)을 담당한다. 녹음 결과는
/// 호출한 쪽에서 `AudioRecording` 모델로 저장한다.
final class AudioRecorderController: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?

    func requestPermissionAndStart(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startRecording()
                }
                completion(granted)
            }
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.record()
            recorder = newRecorder
            recordingURL = url
            isRecording = true
            elapsedTime = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.elapsedTime += 0.1
            }
        } catch {
            recorder = nil
        }
    }

    /// 녹음을 멈추고 녹음된 오디오 데이터와 길이를 돌려준다.
    func stopRecording() -> (data: Data, duration: TimeInterval)? {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false

        guard let url = recordingURL, let data = try? Data(contentsOf: url) else { return nil }
        let duration = elapsedTime
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
        recorder = nil
        return (data, duration)
    }
}

/// 저장된 `AudioRecording`을 재생한다.
final class AudioPlaybackController: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var playingRecordingID: UUID?

    private var player: AVAudioPlayer?

    func play(recording: AudioRecording) {
        guard let data = recording.audioData else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let newPlayer = try AVAudioPlayer(data: data)
            newPlayer.delegate = self
            newPlayer.play()
            player = newPlayer
            isPlaying = true
            playingRecordingID = recording.id
        } catch {
            isPlaying = false
            playingRecordingID = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        playingRecordingID = nil
    }
}

extension AudioPlaybackController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.playingRecordingID = nil
        }
    }
}
