import SwiftUI
import SwiftData

struct NotebookListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Notebook.updatedAt, order: .reverse) private var notebooks: [Notebook]
    @Binding var selection: Notebook?

    @State private var isShowingNewNotebookAlert = false
    @State private var newNotebookTitle = ""

    var body: some View {
        List(selection: $selection) {
            ForEach(notebooks) { notebook in
                Label(notebook.title, systemImage: "book.closed")
                    .tag(notebook)
            }
            .onDelete(perform: deleteNotebooks)
        }
        .navigationTitle("MyNote")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingNewNotebookAlert = true
                } label: {
                    Label("새 노트북", systemImage: "plus")
                }
            }
        }
        .alert("새 노트북", isPresented: $isShowingNewNotebookAlert) {
            TextField("노트북 이름", text: $newNotebookTitle)
            Button("취소", role: .cancel) {
                newNotebookTitle = ""
            }
            Button("만들기") {
                createNotebook()
            }
        }
        .overlay {
            if notebooks.isEmpty {
                ContentUnavailableView(
                    "노트북이 없습니다",
                    systemImage: "book.closed",
                    description: Text("오른쪽 위 + 버튼으로 새 노트북을 만드세요")
                )
            }
        }
    }

    private func createNotebook() {
        let trimmed = newNotebookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let notebook = Notebook(title: trimmed)
        modelContext.insert(notebook)
        newNotebookTitle = ""
        selection = notebook
    }

    private func deleteNotebooks(at offsets: IndexSet) {
        for index in offsets {
            if selection == notebooks[index] {
                selection = nil
            }
            modelContext.delete(notebooks[index])
        }
    }
}
