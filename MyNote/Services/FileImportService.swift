import Foundation
import SwiftData

enum FileImportError: LocalizedError {
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "파일을 읽을 수 없습니다. PDF 형식인지 확인해주세요."
        }
    }
}

/// OneNote 등 다른 앱에서 "PDF로 내보내기"한 파일이나 일반 PDF를 가져와
/// 새 Note로 저장한다. 저장된 Note는 SwiftData + CloudKit을 통해
/// 자동으로 iCloud에 저장되고 다른 기기와 동기화된다.
enum FileImportService {
    static func importPDF(from url: URL, into notebook: Notebook, modelContext: ModelContext) throws -> Note {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw FileImportError.unreadableFile
        }

        let title = url.deletingPathExtension().lastPathComponent
        let note = Note(title: title, kind: .pdf, notebook: notebook)
        note.pdfData = data
        note.sourceFileName = url.lastPathComponent

        modelContext.insert(note)
        notebook.notes.append(note)
        notebook.updatedAt = .now

        return note
    }
}
