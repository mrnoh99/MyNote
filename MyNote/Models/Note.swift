import Foundation
import SwiftData

enum NoteKind: String, Codable {
    case written
    case pdf
}

/// 필기 노트(PDF 노트에는 적용되지 않음)의 캔버스 배경 종이 스타일.
enum NoteBackgroundStyle: String, Codable, CaseIterable, Hashable {
    case blank
    case lined
    case staffPaper

    var displayName: String {
        switch self {
        case .blank: return "빈 배경"
        case .lined: return "줄노트"
        case .staffPaper: return "오선지"
        }
    }

    var systemImage: String {
        switch self {
        case .blank: return "square"
        case .lined: return "text.alignleft"
        case .staffPaper: return "music.note.list"
        }
    }
}

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = "새 노트"
    var kind: NoteKind = NoteKind.written
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var sourceFileName: String?
    var backgroundStyle: NoteBackgroundStyle = NoteBackgroundStyle.blank

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
