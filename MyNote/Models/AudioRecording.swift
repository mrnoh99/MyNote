import Foundation
import SwiftData

/// 노트에 첨부된 음성 메모 한 건.
@Model
final class AudioRecording {
    var id: UUID = UUID()
    var title: String = "음성 메모"
    var duration: Double = 0
    var createdAt: Date = Date.now

    @Attribute(.externalStorage)
    var audioData: Data?

    var note: Note?

    init(title: String = "음성 메모", duration: Double = 0, audioData: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.duration = duration
        self.audioData = audioData
        self.createdAt = .now
    }
}
