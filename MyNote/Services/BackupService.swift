import Foundation
import SwiftData

/// 라이브러리 전체(폴더 구조, 노트북, 노트, 필기, PDF, 페이지별 애플펜슬
/// 주석)를 하나의 JSON 파일로 내보내고(백업) 다시 불러오는(복원) 기능.
/// CloudKit 자동 동기화와는 별개로, 사용자가 원하는 시점에 스냅샷을
/// 파일로 저장/이동할 수 있게 해준다. 복원은 항상 새 폴더/노트북으로
/// 추가되며 기존 데이터를 지우지 않는다.
enum BackupError: LocalizedError {
    case fetchFailed
    case encodingFailed
    case writeFailed
    case unreadableFile
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "백업할 데이터를 불러오지 못했습니다."
        case .encodingFailed:
            return "백업 데이터를 만들지 못했습니다."
        case .writeFailed:
            return "백업 파일을 저장하지 못했습니다."
        case .unreadableFile:
            return "백업 파일을 읽을 수 없습니다."
        case .decodingFailed:
            return "백업 파일 형식이 올바르지 않습니다."
        }
    }
}

private struct BackupPayload: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let folders: [FolderBackup]
    let notebooks: [NotebookBackup]
}

private struct FolderBackup: Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let parentFolderID: UUID?

    init(folder: Folder) {
        id = folder.id
        title = folder.title
        createdAt = folder.createdAt
        updatedAt = folder.updatedAt
        parentFolderID = folder.parentFolder?.id
    }
}

private struct NotebookBackup: Codable {
    let id: UUID
    let title: String
    let colorHex: String
    let createdAt: Date
    let updatedAt: Date
    let folderID: UUID?
    let notes: [NoteBackup]

    init(notebook: Notebook) {
        id = notebook.id
        title = notebook.title
        colorHex = notebook.colorHex
        createdAt = notebook.createdAt
        updatedAt = notebook.updatedAt
        folderID = notebook.folder?.id
        notes = notebook.notes
            .sorted { $0.createdAt < $1.createdAt }
            .map(NoteBackup.init)
    }
}

private struct NoteBackup: Codable {
    let id: UUID
    let title: String
    let kind: NoteKind
    let createdAt: Date
    let updatedAt: Date
    let sourceFileName: String?
    let drawingData: Data?
    let pdfData: Data?
    let pdfAnnotations: [PDFPageAnnotationBackup]

    init(note: Note) {
        id = note.id
        title = note.title
        kind = note.kind
        createdAt = note.createdAt
        updatedAt = note.updatedAt
        sourceFileName = note.sourceFileName
        drawingData = note.drawingData
        pdfData = note.pdfData
        pdfAnnotations = note.pdfAnnotations
            .sorted { $0.pageIndex < $1.pageIndex }
            .map(PDFPageAnnotationBackup.init)
    }
}

private struct PDFPageAnnotationBackup: Codable {
    let id: UUID
    let pageIndex: Int
    let drawingData: Data?

    init(annotation: PDFPageAnnotation) {
        id = annotation.id
        pageIndex = annotation.pageIndex
        drawingData = annotation.drawingData
    }
}

enum BackupService {
    private static let formatVersion = 2

    private static var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// 현재 라이브러리에 있는 모든 폴더/노트북(+노트/필기/PDF)을 백업
    /// 파일(JSON)로 만들어 임시 디렉터리에 쓰고, 파일 URL을 돌려준다.
    /// 호출한 쪽에서 공유 시트 등을 통해 사용자가 원하는 위치(파일 앱,
    /// iCloud Drive 등)에 저장하도록 안내하면 된다.
    static func writeBackupFile(modelContext: ModelContext) throws -> URL {
        let folders: [Folder]
        let notebooks: [Notebook]
        do {
            folders = try modelContext.fetch(FetchDescriptor<Folder>())
            notebooks = try modelContext.fetch(FetchDescriptor<Notebook>())
        } catch {
            throw BackupError.fetchFailed
        }

        let payload = BackupPayload(
            formatVersion: formatVersion,
            exportedAt: .now,
            folders: folders.map(FolderBackup.init),
            notebooks: notebooks.map(NotebookBackup.init)
        )

        let data: Data
        do {
            data = try jsonEncoder.encode(payload)
        } catch {
            throw BackupError.encodingFailed
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let fileName = "MyNote-Backup-\(formatter.string(from: .now)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw BackupError.writeFailed
        }
        return url
    }

    /// 백업 파일을 읽어 새 폴더/노트북들로 복원한다. 기존 폴더/노트북/노트는
    /// 건드리지 않고 추가하는 방식이라 실수로 데이터를 잃을 위험이 없다.
    /// 복원된 노트북 개수를 반환한다.
    @discardableResult
    static func restore(from url: URL, modelContext: ModelContext) throws -> Int {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw BackupError.unreadableFile
        }

        let payload: BackupPayload
        do {
            payload = try jsonDecoder.decode(BackupPayload.self, from: data)
        } catch {
            throw BackupError.decodingFailed
        }

        var restoredFolders: [UUID: Folder] = [:]

        func resolveFolder(_ backupID: UUID) -> Folder? {
            if let existing = restoredFolders[backupID] {
                return existing
            }
            guard let backup = payload.folders.first(where: { $0.id == backupID }) else {
                return nil
            }
            let parent = backup.parentFolderID.flatMap(resolveFolder)
            let newFolder = Folder(title: backup.title, parentFolder: parent)
            newFolder.createdAt = backup.createdAt
            newFolder.updatedAt = backup.updatedAt
            modelContext.insert(newFolder)
            restoredFolders[backupID] = newFolder
            return newFolder
        }

        for folderBackup in payload.folders {
            _ = resolveFolder(folderBackup.id)
        }

        for notebookBackup in payload.notebooks {
            let targetFolder = notebookBackup.folderID.flatMap { restoredFolders[$0] }
            let notebook = Notebook(title: notebookBackup.title, colorHex: notebookBackup.colorHex, folder: targetFolder)
            notebook.createdAt = notebookBackup.createdAt
            notebook.updatedAt = notebookBackup.updatedAt
            modelContext.insert(notebook)

            for noteBackup in notebookBackup.notes {
                let note = Note(title: noteBackup.title, kind: noteBackup.kind, notebook: notebook)
                note.createdAt = noteBackup.createdAt
                note.updatedAt = noteBackup.updatedAt
                note.sourceFileName = noteBackup.sourceFileName
                note.drawingData = noteBackup.drawingData
                note.pdfData = noteBackup.pdfData
                modelContext.insert(note)

                for annotationBackup in noteBackup.pdfAnnotations {
                    let annotation = PDFPageAnnotation(
                        pageIndex: annotationBackup.pageIndex,
                        drawingData: annotationBackup.drawingData
                    )
                    annotation.note = note
                    modelContext.insert(annotation)
                }
            }
        }

        return payload.notebooks.count
    }
}
