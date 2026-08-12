import Foundation
import SwiftData

/// 노트 캔버스 위에 자유롭게 배치하는 이미지. 위치/크기는 캔버스
/// 좌표계(포인트) 기준이며 사용자가 드래그로 옮기고 모서리로 크기를
/// 조절할 수 있다.
///
/// `pageIndex`는 이 첨부가 속한 페이지 번호다(PDF 노트의 페이지, 또는
/// 필기 노트의 `NotePage.pageIndex`). 여러 페이지 도입 이전에 만들어진
/// 레거시 첨부는 nil일 수 있는데, 이 경우 0번 페이지에 속한 것으로
/// 취급한다.
@Model
final class ImageAttachment {
    var id: UUID = UUID()
    var positionX: Double = 100
    var positionY: Double = 100
    var width: Double = 200
    var height: Double = 200
    var pageIndex: Int?
    var createdAt: Date = Date.now

    @Attribute(.externalStorage)
    var imageData: Data?

    var note: Note?

    init(
        imageData: Data,
        positionX: Double = 100,
        positionY: Double = 100,
        width: Double = 200,
        height: Double = 200,
        pageIndex: Int? = nil
    ) {
        self.id = UUID()
        self.imageData = imageData
        self.positionX = positionX
        self.positionY = positionY
        self.width = width
        self.height = height
        self.pageIndex = pageIndex
        self.createdAt = .now
    }
}
