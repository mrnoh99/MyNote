import SwiftUI
import SwiftData

struct RootView: View {
    @State private var selectedNotebook: Notebook?

    var body: some View {
        NavigationSplitView {
            NavigationStack {
                FolderBrowserView(folder: nil, selectedNotebook: $selectedNotebook)
            }
        } detail: {
            if let selectedNotebook {
                NotebookDetailView(notebook: selectedNotebook)
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

#Preview {
    RootView()
        .modelContainer(for: [Folder.self, Notebook.self, Note.self, PDFPageAnnotation.self], inMemory: true)
}
