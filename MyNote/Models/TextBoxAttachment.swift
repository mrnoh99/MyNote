import Foundation
import SwiftData

/// 필기 노트 캔버스 위에 자유롭게 배치하는 입력 텍스트 상자
/// (손글씨가 아니라 키보드로 입력하는 일반 텍스트).
@Model
final class TextBoxAttachment {
    var id: UUID = UUID()
    var text: String = ""
    var positionX: Double = 100
    var positionY: Double = 100
    var width: Double = 220
    var height: Double = 100
    var fontSize: Double = 17
    var colorHex: String = "#000000"
    var createdAt: Date = Date.now

    var note: Note?

    init(
        text: String = "",
        positionX: Double = 100,
        positionY: Double = 100,
        width: Double = 220,
        height: Double = 100
    ) {
        self.id = UUID()
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.width = width
        self.height = height
        self.createdAt = .now
    }
}
