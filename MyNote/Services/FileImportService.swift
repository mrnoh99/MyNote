import Foundation
import PDFKit
import SwiftData

enum FileImportError: LocalizedError {
    case unreadableFile
    case notAPDF

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "파일을 읽을 수 없습니다. 다시 시도해주세요."
        case .notAPDF:
            return "PDF 형식이 아닙니다. \(FileImportService.unsupportedFormatGuidance)"
        }
    }
}

/// OneNote 등 다른 앱에서 "PDF로 내보내기"한 파일이나 일반 PDF를 가져와
/// 새 Note로 저장한다. 저장된 Note는 SwiftData + CloudKit을 통해
/// 자동으로 iCloud에 저장되고 다른 기기와 동기화된다.
enum FileImportService {
    /// PDF가 아닌 다른 문서 형식을 가져오려 할 때 보여줄 안내 문구.
    /// MyNote는 PDFKit 기반이라 PDF만 페이지 단위로 열어 애플펜슬 필기를
    /// 겹칠 수 있고, Word/PPT/한글/Keynote/Pages 같은 형식은 직접 열 수 없다.
    static let unsupportedFormatGuidance =
        "Word, PowerPoint, 아래한글(HWP), Keynote, Pages, OneNote 같은 파일은 해당 앱에서 " +
        "'PDF로 내보내기' 또는 '인쇄 > PDF로 저장' 기능으로 먼저 PDF를 만든 뒤 가져와 주세요."

    static func importPDF(from url: URL, into notebook: Notebook, modelContext: ModelContext) throws -> Note {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw FileImportError.unreadableFile
        }

        guard PDFDocument(data: data) != nil else {
            throw FileImportError.notAPDF
        }

        let title = url.deletingPathExtension().lastPathComponent
        let note = Note(title: title, kind: .pdf, notebook: notebook)
        note.pdfData = data
        note.sourceFileName = url.lastPathComponent

        modelContext.insert(note)
        notebook.updatedAt = .now

        return note
    }
}
