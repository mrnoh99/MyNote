import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct NotebookDetailView: View {
    @Bindable var notebook: Notebook
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingImporter = false
    @State private var navigationPath = NavigationPath()
    @State private var importErrorMessage: String?
    @State private var isShowingFormatGuidance = false

    private var sortedNotes: [Note] {
        notebook.notes.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(sortedNotes) { note in
                    NavigationLink(value: note) {
                        NoteRow(note: note)
                    }
                }
                .onDelete(perform: deleteNotes)
            }
            .navigationTitle(notebook.title)
            .navigationDestination(for: Note.self) { note in
                if note.kind == .pdf {
                    PDFAnnotationView(note: note)
                } else {
                    NoteEditorView(note: note)
                }
            }
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
            .overlay {
                if notebook.notes.isEmpty {
                    ContentUnavailableView(
                        "노트가 없습니다",
                        systemImage: "note.text",
                        description: Text("+ 버튼으로 필기 노트를 만들거나 PDF를 가져오세요. Word/PPT/한글/Keynote/Pages/OneNote는 각 앱에서 PDF로 내보낸 뒤 가져올 수 있어요.")
                    )
                }
            }
        }
    }

    private func createWrittenNote() {
        let note = Note(title: "새 노트", kind: .written, notebook: notebook)
        modelContext.insert(note)
        notebook.notes.append(note)
        notebook.updatedAt = .now
        navigationPath.append(note)
    }

    private func handleImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let note = try FileImportService.importPDF(from: url, into: notebook, modelContext: modelContext)
            navigationPath.append(note)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedNotes[index])
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
        }
    }
}
