import Foundation
import SwiftData

@Model
final class PDFPageAnnotation {
    var id: UUID = UUID()
    var pageIndex: Int = 0

    @Attribute(.externalStorage)
    var drawingData: Data?

    var note: Note?

    init(pageIndex: Int, drawingData: Data? = nil) {
        self.id = UUID()
        self.pageIndex = pageIndex
        self.drawingData = drawingData
    }
}
