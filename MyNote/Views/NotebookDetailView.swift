import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct NotebookDetailView: View {
    @Bindable var notebook: Notebook
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingImporter = false
    @State private var importErrorMessage: String?
    @State private var isShowingFormatGuidance = false

    @State private var movingNote: Note?
    @State private var duplicatingNote: Note?

    /// 열려 있는 노트들("탭"). 이 노트북 안에서 연 노트만 추적한다.
    @State private var openNotes: [Note] = []
    @State private var activeNote: Note?
    @State private var isShowingNoteListSheet = false

    private var sortedNotes: [Note] {
        notebook.notes.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !openNotes.isEmpty {
                tabBar
                Divider()
            }

            if let activeNote {
                Group {
                    if activeNote.kind == .pdf {
                        PDFAnnotationView(note: activeNote)
                    } else {
                        NoteEditorView(note: activeNote)
                    }
                }
                .id(activeNote.id)
            } else {
                noteListView
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
                closeTab(note)
            }
        }
        .sheet(item: $duplicatingNote) { note in
            NotebookPickerView(itemTitle: note.title, excluding: nil) { destination in
                OrganizationService.duplicateNote(note, into: destination, modelContext: modelContext)
            }
        }
        .sheet(isPresented: $isShowingNoteListSheet) {
            NavigationStack {
                noteListView
                    .navigationTitle("노트 선택")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") { isShowingNoteListSheet = false }
                        }
                    }
            }
        }
    }

    // MARK: - 탭 바

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(openNotes) { note in
                    tabChip(note)
                }
                Button {
                    isShowingNoteListSheet = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }

    private func tabChip(_ note: Note) -> some View {
        let isActive = activeNote == note
        return HStack(spacing: 6) {
            Image(systemName: note.kind == .pdf ? "doc.richtext" : "pencil.and.scribble")
                .font(.caption)
            Text(note.title)
                .font(.caption)
                .lineLimit(1)
            Button {
                closeTab(note)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            activeNote = note
        }
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
            Button(role: .destructive) {
                delete(note)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    // MARK: - 노트 목록

    private var noteListView: some View {
        List {
            ForEach(sortedNotes) { note in
                Button {
                    openTab(note)
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
    }

    // MARK: - 탭 열기/닫기

    private func openTab(_ note: Note) {
        if !openNotes.contains(note) {
            openNotes.append(note)
        }
        activeNote = note
        isShowingNoteListSheet = false
    }

    private func closeTab(_ note: Note) {
        openNotes.removeAll { $0 == note }
        if activeNote == note {
            activeNote = openNotes.last
        }
    }

    // MARK: - 액션

    private func createWrittenNote() {
        let note = Note(title: "새 노트", kind: .written, notebook: notebook)
        modelContext.insert(note)
        notebook.updatedAt = .now
        openTab(note)
    }

    private func handleImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let note = try FileImportService.importPDF(from: url, into: notebook, modelContext: modelContext)
            openTab(note)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func delete(_ note: Note) {
        closeTab(note)
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
