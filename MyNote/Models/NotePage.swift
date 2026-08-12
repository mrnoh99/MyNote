import Foundation
import SwiftData

/// 필기 노트의 한 페이지. 필기 노트는 여러 페이지를 가질 수 있고,
/// 페이지마다 독립된 PencilKit 드로잉을 저장한다. PDF 노트의
/// `PDFPageAnnotation`과 같은 역할을 필기 노트 쪽에서 담당한다.
@Model
final class NotePage {
    var id: UUID = UUID()
    var pageIndex: Int = 0
    var createdAt: Date = Date.now

    @Attribute(.externalStorage)
    var drawingData: Data?

    var note: Note?

    init(pageIndex: Int, drawingData: Data? = nil) {
        self.id = UUID()
        self.pageIndex = pageIndex
        self.drawingData = drawingData
        self.createdAt = .now
    }
}
