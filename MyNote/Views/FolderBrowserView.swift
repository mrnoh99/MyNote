import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 폴더 트리를 탐색하는 화면. 사이드바의 루트(folder == nil)로도 쓰이고,
/// 폴더를 탭해서 더 들어가면 같은 뷰가 그 하위 폴더로 다시 생성되어 재사용된다.
struct FolderBrowserView: View {
    let folder: Folder?
    @Binding var selectedNotebook: Notebook?
    @ObservedObject var workspace: NoteWorkspace

    @Environment(\.modelContext) private var modelContext

    @Query private var subfolders: [Folder]
    @Query private var notebooks: [Notebook]

    @State private var isShowingNewFolderAlert = false
    @State private var newFolderTitle = ""
    @State private var isShowingNewNotebookAlert = false
    @State private var newNotebookTitle = ""

    @State private var renamingFolder: Folder?
    @State private var renamingNotebook: Notebook?
    @State private var renameText = ""

    @State private var movingFolder: Folder?
    @State private var movingNotebook: Notebook?

    @State private var isShowingRestoreImporter = false
    @State private var isShowingBackupShareSheet = false
    @State private var backupShareURL: URL?
    @State private var backupErrorMessage: String?
    @State private var restoreResultMessage: String?

    init(folder: Folder?, selectedNotebook: Binding<Notebook?>, workspace: NoteWorkspace) {
        self.folder = folder
        self._selectedNotebook = selectedNotebook
        self.workspace = workspace

        let folderID = folder?.id
        _subfolders = Query(
            filter: #Predicate<Folder> { $0.parentFolder?.id == folderID },
            sort: \Folder.title
        )
        _notebooks = Query(
            filter: #Predicate<Notebook> { $0.folder?.id == folderID },
            sort: \Notebook.updatedAt,
            order: .reverse
        )
    }

    var body: some View {
        List {
            if !subfolders.isEmpty {
                Section("폴더") {
                    ForEach(subfolders) { subfolder in
                        NavigationLink(value: subfolder) {
                            Label(subfolder.title, systemImage: "folder")
                        }
                        .contextMenu {
                            Button {
                                startRenaming(subfolder)
                            } label: {
                                Label("이름 변경", systemImage: "pencil")
                            }
                            Button {
                                movingFolder = subfolder
                            } label: {
                                Label("이동", systemImage: "folder.badge.gearshape")
                            }
                            Button(role: .destructive) {
                                delete(folder: subfolder)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !notebooks.isEmpty {
                Section("노트북") {
                    ForEach(notebooks) { notebook in
                        Button {
                            selectedNotebook = notebook
                        } label: {
                            HStack {
                                Label(notebook.title, systemImage: "book.closed")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedNotebook == notebook {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .contextMenu {
                            Button {
                                startRenaming(notebook)
                            } label: {
                                Label("이름 변경", systemImage: "pencil")
                            }
                            Button {
                                movingNotebook = notebook
                            } label: {
                                Label("이동", systemImage: "folder.badge.gearshape")
                            }
                            Button {
                                duplicate(notebook: notebook)
                            } label: {
                                Label("복제", systemImage: "plus.square.on.square")
                            }
                            Button(role: .destructive) {
                                delete(notebook: notebook)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if subfolders.isEmpty && notebooks.isEmpty {
                ContentUnavailableView(
                    "비어 있습니다",
                    systemImage: "folder",
                    description: Text("오른쪽 위 + 버튼으로 폴더나 노트북을 만드세요")
                )
            }
        }
        .navigationTitle(folder?.title ?? "MyNote")
        .navigationDestination(for: Folder.self) { subfolder in
            FolderBrowserView(folder: subfolder, selectedNotebook: $selectedNotebook, workspace: workspace)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isShowingNewFolderAlert = true
                    } label: {
                        Label("새 폴더", systemImage: "folder.badge.plus")
                    }
                    Button {
                        isShowingNewNotebookAlert = true
                    } label: {
                        Label("새 노트북", systemImage: "book.closed")
                    }
                    Divider()
                    Button {
                        exportBackup()
                    } label: {
                        Label("백업 내보내기", systemImage: "square.and.arrow.up")
                    }
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
        .alert("새 폴더", isPresented: $isShowingNewFolderAlert) {
            TextField("폴더 이름", text: $newFolderTitle)
            Button("취소", role: .cancel) { newFolderTitle = "" }
            Button("만들기") { createFolder() }
        }
        .alert("새 노트북", isPresented: $isShowingNewNotebookAlert) {
            TextField("노트북 이름", text: $newNotebookTitle)
            Button("취소", role: .cancel) { newNotebookTitle = "" }
            Button("만들기") { createNotebook() }
        }
        .alert(
            "이름 변경",
            isPresented: Binding(
                get: { renamingFolder != nil || renamingNotebook != nil },
                set: { isPresented in
                    if !isPresented {
                        renamingFolder = nil
                        renamingNotebook = nil
                    }
                }
            )
        ) {
            TextField("이름", text: $renameText)
            Button("취소", role: .cancel) {
                renamingFolder = nil
                renamingNotebook = nil
            }
            Button("변경") { commitRename() }
        }
        .sheet(item: $movingFolder) { folderToMove in
            FolderPickerView(itemTitle: folderToMove.title, excluding: folderToMove) { destination in
                move(folder: folderToMove, to: destination)
            }
        }
        .sheet(item: $movingNotebook) { notebookToMove in
            FolderPickerView(itemTitle: notebookToMove.title, excluding: nil) { destination in
                move(notebook: notebookToMove, to: destination)
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
    }

    private func createFolder() {
        let trimmed = newFolderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newFolder = Folder(title: trimmed, parentFolder: folder)
        modelContext.insert(newFolder)
        newFolderTitle = ""
    }

    private func createNotebook() {
        let trimmed = newNotebookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let notebook = Notebook(title: trimmed, folder: folder)
        modelContext.insert(notebook)
        newNotebookTitle = ""
        selectedNotebook = notebook
    }

    private func startRenaming(_ folder: Folder) {
        renamingFolder = folder
        renameText = folder.title
    }

    private func startRenaming(_ notebook: Notebook) {
        renamingNotebook = notebook
        renameText = notebook.title
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            renamingFolder = nil
            renamingNotebook = nil
        }
        guard !trimmed.isEmpty else { return }
        if let renamingFolder {
            renamingFolder.title = trimmed
            renamingFolder.updatedAt = .now
        }
        if let renamingNotebook {
            renamingNotebook.title = trimmed
            renamingNotebook.updatedAt = .now
        }
    }

    private func delete(folder: Folder) {
        closeTabs(inFolderTree: folder)
        modelContext.delete(folder)
    }

    private func delete(notebook: Notebook) {
        if selectedNotebook == notebook {
            selectedNotebook = nil
        }
        closeTabs(in: notebook)
        modelContext.delete(notebook)
    }

    /// 삭제로 인해 사라질 노트가 탭으로 열려 있으면 먼저 닫는다.
    /// (삭제된 SwiftData 객체를 탭이 계속 들고 있으면 안 된다.)
    private func closeTabs(in notebook: Notebook) {
        for note in notebook.notes {
            workspace.close(note)
        }
    }

    private func closeTabs(inFolderTree folder: Folder) {
        for notebook in folder.notebooks {
            closeTabs(in: notebook)
        }
        for subfolder in folder.subfolders {
            closeTabs(inFolderTree: subfolder)
        }
    }

    private func duplicate(notebook: Notebook) {
        OrganizationService.duplicateNotebook(notebook, into: notebook.folder, modelContext: modelContext)
    }

    private func move(folder movedFolder: Folder, to destination: Folder?) {
        movedFolder.parentFolder = destination
        movedFolder.updatedAt = .now
    }

    private func move(notebook: Notebook, to destination: Folder?) {
        notebook.folder = destination
        notebook.updatedAt = .now
    }

    private func exportBackup() {
        do {
            backupShareURL = try BackupService.writeBackupFile(modelContext: modelContext)
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
