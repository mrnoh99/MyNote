import Foundation
import SwiftData

enum NoteKind: String, Codable {
    case written
    case pdf
}

/// 필기 노트(PDF 노트에는 적용되지 않음)의 캔버스 배경 종이 스타일.
/// OneNote의 기본 페이지 스타일(백지/줄친 종이/모눈종이/점선지)에 대응하고,
/// 손글씨 악보 작성을 위한 오선지를 더했다.
enum NoteBackgroundStyle: String, Codable, CaseIterable, Hashable {
    case blank
    case lined
    case dotGrid
    case squareGrid
    case staffPaper

    var displayName: String {
        switch self {
        case .blank: return "백지"
        case .lined: return "줄친 종이"
        case .dotGrid: return "점선지"
        case .squareGrid: return "모눈종이"
        case .staffPaper: return "오선지"
        }
    }

    var systemImage: String {
        switch self {
        case .blank: return "doc.plaintext"
        case .lined: return "text.alignleft"
        case .dotGrid: return "circle.grid.3x3"
        case .squareGrid: return "grid"
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

    /// 여러 페이지 도입 이전(단일 페이지) 필기 노트의 레거시 필드.
    /// 새로 만드는 필기 노트는 `pages`(NotePage)를 쓰고, 이 필드는 첫
    /// 실행 시 `NotePage(pageIndex: 0)`로 자동 이전된다.
    @Attribute(.externalStorage)
    var drawingData: Data?

    @Attribute(.externalStorage)
    var pdfData: Data?

    // CloudKit 동기화는 to-many 관계도 반드시 옵셔널 타입이어야 한다.
    // 읽을 때는 `note.pdfAnnotations ?? []`처럼 쓴다.
    @Relationship(deleteRule: .cascade, inverse: \NotePage.note)
    var pages: [NotePage]? = []

    @Relationship(deleteRule: .cascade, inverse: \PDFPageAnnotation.note)
    var pdfAnnotations: [PDFPageAnnotation]? = []

    @Relationship(deleteRule: .cascade, inverse: \ImageAttachment.note)
    var imageAttachments: [ImageAttachment]? = []

    @Relationship(deleteRule: .cascade, inverse: \TextBoxAttachment.note)
    var textBoxAttachments: [TextBoxAttachment]? = []

    @Relationship(deleteRule: .cascade, inverse: \AudioRecording.note)
    var audioRecordings: [AudioRecording]? = []

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
