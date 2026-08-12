import Foundation
import SwiftData

/// 노트북/노트를 다른 위치로 복제(복사)할 때 쓰는 헬퍼.
///
/// SwiftData 관계는 한쪽(예: `note.notebook = notebook`)만 설정하면
/// 반대편 배열(`notebook.notes`)에도 자동으로 반영되므로, 이 파일에서는
/// 절대 양쪽을 모두 수동으로 채우지 않는다(중복 삽입 방지).
enum OrganizationService {
    @discardableResult
    static func duplicateNotebook(_ notebook: Notebook, into folder: Folder?, modelContext: ModelContext) -> Notebook {
        let copy = Notebook(title: notebook.title + " 복사본", colorHex: notebook.colorHex, folder: folder)
        modelContext.insert(copy)

        for note in notebook.notes {
            duplicateNote(note, into: copy, modelContext: modelContext, renaming: false)
        }

        return copy
    }

    @discardableResult
    static func duplicateNote(
        _ note: Note,
        into notebook: Notebook,
        modelContext: ModelContext,
        renaming: Bool = true
    ) -> Note {
        let title = renaming ? note.title + " 복사본" : note.title
        let copy = Note(title: title, kind: note.kind, notebook: notebook)
        copy.sourceFileName = note.sourceFileName
        copy.drawingData = note.drawingData
        copy.pdfData = note.pdfData
        modelContext.insert(copy)

        for annotation in note.pdfAnnotations {
            let annotationCopy = PDFPageAnnotation(pageIndex: annotation.pageIndex, drawingData: annotation.drawingData)
            annotationCopy.note = copy
            modelContext.insert(annotationCopy)
        }

        return copy
    }
}
