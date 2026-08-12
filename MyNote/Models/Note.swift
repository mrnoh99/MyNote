import Foundation
import SwiftData

enum NoteKind: String, Codable {
    case written
    case pdf
}

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = "새 노트"
    var kind: NoteKind = NoteKind.written
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var sourceFileName: String?

    @Attribute(.externalStorage)
    var drawingData: Data?

    @Attribute(.externalStorage)
    var pdfData: Data?

    @Relationship(deleteRule: .cascade, inverse: \PDFPageAnnotation.note)
    var pdfAnnotations: [PDFPageAnnotation] = []

    var notebook: Notebook?

    init(title: String, kind: NoteKind, notebook: Notebook? = nil) {
        self.id = UUID()
        self.title = title
        self.kind = kind
        self.createdAt = .now
        self.updatedAt = .now
        self.notebook = notebook
    }
}
