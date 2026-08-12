import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 노트북 안의 노트 목록. 탭으로 열린 노트 자체는 앱 전체가 공유하는
/// `NoteWorkspace`가 들고 있고(그래야 다른 노트북으로 이동해도 탭이
/// 유지된다), 이 뷰는 그 워크스페이스에 노트를 여는 역할만 한다.
struct NotebookDetailView: View {
    @Bindable var notebook: Notebook
    @ObservedObject var workspace: NoteWorkspace
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingImporter = false
    @State private var importErrorMessage: String?
    @State private var isShowingFormatGuidance = false

    @State private var movingNote: Note?
    @State private var duplicatingNote: Note?

    private var sortedNotes: [Note] {
        notebook.notes.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        List {
            ForEach(sortedNotes) { note in
                Button {
                    workspace.open(note)
                } label: {
                    NoteRow(note: note)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        movingNote = note
                    } label: {
                        Label("다른 노트북으로 이동", systemImage: "folder.badge.gearshape")
                    }
                    Button {
                        duplicatingNote = note
                    } label: {
                        Label("다른 노트북으로 복제", systemImage: "plus.square.on.square")
                    }
                    Button {
                        OrganizationService.duplicateNote(note, into: notebook, modelContext: modelContext)
                    } label: {
                        Label("이 노트북에 복제", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        delete(note)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: deleteNotes)
        }
        .overlay {
            if notebook.notes.isEmpty {
                ContentUnavailableView(
                    "노트가 없습니다",
                    systemImage: "note.text",
                    description: Text("+ 버튼으로 필기 노트를 만들거나 PDF를 가져오세요. Word/PPT/한글/Keynote/Pages/OneNote는 각 앱에서 PDF로 내보낸 뒤 가져올 수 있어요.")
                )
            }
        }
        .navigationTitle(notebook.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        createWrittenNote()
                    } label: {
                        Label("새 필기 노트", systemImage: "pencil.tip")
                    }
                    Button {
                        isShowingImporter = true
                    } label: {
                        Label("PDF 가져오기", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        isShowingFormatGuidance = true
                    } label: {
                        Label("가져올 수 있는 파일 형식 안내", systemImage: "questionmark.circle")
                    }
                } label: {
                    Label("추가", systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert(
            "가져오기 실패",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("확인") { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
        .alert("가져올 수 있는 파일 형식", isPresented: $isShowingFormatGuidance) {
            Button("확인") { isShowingFormatGuidance = false }
        } message: {
            Text("PDF 파일만 가져올 수 있어요.\n\(FileImportService.unsupportedFormatGuidance)")
        }
        .sheet(item: $movingNote) { note in
            NotebookPickerView(itemTitle: note.title, excluding: notebook) { destination in
                note.notebook = destination
                note.updatedAt = .now
                workspace.close(note)
            }
        }
        .sheet(item: $duplicatingNote) { note in
            NotebookPickerView(itemTitle: note.title, excluding: nil) { destination in
                OrganizationService.duplicateNote(note, into: destination, modelContext: modelContext)
            }
        }
    }

    private func createWrittenNote() {
        let note = Note(title: "새 노트", kind: .written, notebook: notebook)
        modelContext.insert(note)
        notebook.updatedAt = .now
        workspace.open(note)
    }

    private func handleImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let note = try FileImportService.importPDF(from: url, into: notebook, modelContext: modelContext)
            workspace.open(note)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func delete(_ note: Note) {
        workspace.close(note)
        modelContext.delete(note)
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            delete(sortedNotes[index])
        }
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack {
            Image(systemName: note.kind == .pdf ? "doc.richtext" : "pencil.and.scribble")
                .foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text(note.title)
                Text(note.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
