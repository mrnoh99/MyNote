import Foundation
import SwiftData

/// 노트 캔버스 위에 자유롭게 배치하는 입력 텍스트 상자
/// (손글씨가 아니라 키보드로 입력하는 일반 텍스트).
///
/// `pageIndex`가 nil이면 필기 노트에 속한 첨부(페이지 개념이 없음),
/// 값이 있으면 PDF 노트의 해당 페이지에만 나타나는 첨부다.
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
    var pageIndex: Int?
    var createdAt: Date = Date.now

    var note: Note?

    init(
        text: String = "",
        positionX: Double = 100,
        positionY: Double = 100,
        width: Double = 220,
        height: Double = 100,
        pageIndex: Int? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.width = width
        self.height = height
        self.pageIndex = pageIndex
        self.createdAt = .now
    }
}
