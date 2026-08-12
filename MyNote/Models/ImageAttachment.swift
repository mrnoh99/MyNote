import Foundation
import SwiftData

/// 필기 노트 캔버스 위에 자유롭게 배치하는 이미지. 위치/크기는 캔버스
/// 좌표계(포인트) 기준이며 사용자가 드래그로 옮기고 모서리로 크기를
/// 조절할 수 있다.
@Model
final class ImageAttachment {
    var id: UUID = UUID()
    var positionX: Double = 100
    var positionY: Double = 100
    var width: Double = 200
    var height: Double = 200
    var createdAt: Date = Date.now

    @Attribute(.externalStorage)
    var imageData: Data?

    var note: Note?

    init(
        imageData: Data,
        positionX: Double = 100,
        positionY: Double = 100,
        width: Double = 200,
        height: Double = 200
    ) {
        self.id = UUID()
        self.imageData = imageData
        self.positionX = positionX
        self.positionY = positionY
        self.width = width
        self.height = height
        self.createdAt = .now
    }
}
