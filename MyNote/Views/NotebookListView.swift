import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct NotebookListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Notebook.updatedAt, order: .reverse) private var notebooks: [Notebook]
    @Binding var selection: Notebook?

    @State private var isShowingNewNotebookAlert = false
    @State private var newNotebookTitle = ""

    @State private var isShowingRestoreImporter = false
    @State private var isShowingBackupShareSheet = false
    @State private var backupShareURL: URL?
    @State private var backupErrorMessage: String?
    @State private var restoreResultMessage: String?

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
                Menu {
                    Button {
                        isShowingNewNotebookAlert = true
                    } label: {
                        Label("새 노트북", systemImage: "plus")
                    }
                    Divider()
                    Button {
                        exportBackup()
                    } label: {
                        Label("백업 내보내기", systemImage: "square.and.arrow.up")
                    }
                    .disabled(notebooks.isEmpty)
                    Button {
                        isShowingRestoreImporter = true
                    } label: {
                        Label("백업에서 복원", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label("추가", systemImage: "plus")
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
        .fileImporter(
            isPresented: $isShowingRestoreImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleRestore(result: result)
        }
        .sheet(isPresented: $isShowingBackupShareSheet) {
            if let backupShareURL {
                ActivityView(activityItems: [backupShareURL])
            }
        }
        .alert(
            "백업/복원 실패",
            isPresented: Binding(
                get: { backupErrorMessage != nil },
                set: { if !$0 { backupErrorMessage = nil } }
            )
        ) {
            Button("확인") { backupErrorMessage = nil }
        } message: {
            Text(backupErrorMessage ?? "")
        }
        .alert(
            "복원 완료",
            isPresented: Binding(
                get: { restoreResultMessage != nil },
                set: { if !$0 { restoreResultMessage = nil } }
            )
        ) {
            Button("확인") { restoreResultMessage = nil }
        } message: {
            Text(restoreResultMessage ?? "")
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

    private func exportBackup() {
        do {
            backupShareURL = try BackupService.writeBackupFile(notebooks: notebooks)
            isShowingBackupShareSheet = true
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }

    private func handleRestore(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let count = try BackupService.restore(from: url, modelContext: modelContext)
            restoreResultMessage = "노트북 \(count)개를 복원했습니다."
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }
}
