import SwiftUI
import SwiftData

/// 노트에 딸린 음성 메모를 녹음/재생/삭제하는 시트.
struct AudioRecordingsSheet: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var recorderController = AudioRecorderController()
    @StateObject private var playbackController = AudioPlaybackController()
    @State private var permissionDeniedMessage: String?

    private var sortedRecordings: [AudioRecording] {
        note.audioRecordings.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    recordButton
                }

                if !sortedRecordings.isEmpty {
                    Section("녹음 목록") {
                        ForEach(sortedRecordings) { recording in
                            recordingRow(recording)
                        }
                        .onDelete(perform: deleteRecordings)
                    }
                }
            }
            .navigationTitle("음성 메모")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        playbackController.stop()
                        dismiss()
                    }
                }
            }
            .alert(
                "마이크 권한 필요",
                isPresented: Binding(
                    get: { permissionDeniedMessage != nil },
                    set: { if !$0 { permissionDeniedMessage = nil } }
                )
            ) {
                Button("확인") { permissionDeniedMessage = nil }
            } message: {
                Text(permissionDeniedMessage ?? "")
            }
        }
    }

    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            HStack {
                Image(systemName: recorderController.isRecording ? "stop.circle.fill" : "record.circle")
                    .foregroundStyle(recorderController.isRecording ? .red : .accentColor)
                    .font(.title2)
                Text(recorderController.isRecording ? "녹음 중지 (\(formattedElapsed))" : "새 녹음 시작")
            }
        }
    }

    private var formattedElapsed: String {
        formattedDuration(recorderController.elapsedTime)
    }

    private func toggleRecording() {
        if recorderController.isRecording {
            if let result = recorderController.stopRecording() {
                let recording = AudioRecording(duration: result.duration, audioData: result.data)
                recording.note = note
                modelContext.insert(recording)
                note.updatedAt = .now
            }
        } else {
            recorderController.requestPermissionAndStart { granted in
                if !granted {
                    permissionDeniedMessage = "설정 앱 > MyNote > 마이크에서 접근을 허용해주세요."
                }
            }
        }
    }

    private func recordingRow(_ recording: AudioRecording) -> some View {
        HStack {
            Button {
                if playbackController.playingRecordingID == recording.id {
                    playbackController.stop()
                } else {
                    playbackController.play(recording: recording)
                }
            } label: {
                Image(systemName: playbackController.playingRecordingID == recording.id ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
            }
            VStack(alignment: .leading) {
                Text(recording.title)
                Text(formattedDuration(recording.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = sortedRecordings[index]
            if playbackController.playingRecordingID == recording.id {
                playbackController.stop()
            }
            modelContext.delete(recording)
        }
    }
}
