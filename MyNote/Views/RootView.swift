import SwiftUI
import SwiftData

struct RootView: View {
    @State private var selectedNotebook: Notebook?
    @StateObject private var workspace = NoteWorkspace()

    var body: some View {
        NavigationSplitView {
            NavigationStack {
                FolderBrowserView(folder: nil, selectedNotebook: $selectedNotebook, workspace: workspace)
            }
        } detail: {
            VStack(spacing: 0) {
                if !workspace.openNotes.isEmpty {
                    NoteTabBarView(workspace: workspace)
                    Divider()
                }

                if let activeNote = workspace.activeNote {
                    Group {
                        if activeNote.kind == .pdf {
                            PDFAnnotationView(note: activeNote)
                        } else {
                            NoteEditorView(note: activeNote)
                        }
                    }
                    .id(activeNote.id)
                } else if let selectedNotebook {
                    NotebookDetailView(notebook: selectedNotebook, workspace: workspace)
                        .id(selectedNotebook.id)
                } else {
                    ContentUnavailableView(
                        "노트북을 선택하세요",
                        systemImage: "book.closed",
                        description: Text("왼쪽 목록에서 노트북을 선택하거나 새로 만드세요")
                    )
                }
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(
            for: [
                Folder.self, Notebook.self, Note.self, PDFPageAnnotation.self,
                ImageAttachment.self, TextBoxAttachment.self, AudioRecording.self,
                NotePage.self,
            ],
            inMemory: true
        )
}
