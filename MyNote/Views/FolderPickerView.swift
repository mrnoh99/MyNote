import SwiftUI
import SwiftData

/// "이동" 액션에서 목적지 폴더를 고르는 모달 시트.
/// 폴더를 옮길 때는 자기 자신과 하위 폴더로는 이동할 수 없도록 제외한다.
struct FolderPickerView: View {
    let itemTitle: String
    let excluding: Folder?
    let onSelect: (Folder?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Folder.title) private var allFolders: [Folder]

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                    dismiss()
                } label: {
                    Label("최상위(루트)", systemImage: "house")
                }

                ForEach(navigableFolders, id: \.folder.id) { entry in
                    Button {
                        onSelect(entry.folder)
                        dismiss()
                    } label: {
                        Label(entry.folder.title, systemImage: "folder")
                            .padding(.leading, CGFloat(entry.depth) * 16)
                    }
                }
            }
            .navigationTitle("\"\(itemTitle)\" 이동")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .overlay {
                if navigableFolders.isEmpty {
                    ContentUnavailableView(
                        "이동할 폴더가 없습니다",
                        systemImage: "folder",
                        description: Text("최상위(루트)로 이동하거나 먼저 폴더를 만드세요")
                    )
                }
            }
        }
    }

    private var navigableFolders: [(folder: Folder, depth: Int)] {
        var result: [(folder: Folder, depth: Int)] = []

        func visit(_ folder: Folder, depth: Int) {
            guard !isExcluded(folder) else { return }
            result.append((folder, depth))
            for child in folder.subfolders.sorted(by: { $0.title < $1.title }) {
                visit(child, depth: depth + 1)
            }
        }

        let roots = allFolders.filter { $0.parentFolder == nil }.sorted { $0.title < $1.title }
        for root in roots {
            visit(root, depth: 0)
        }
        return result
    }

    private func isExcluded(_ folder: Folder) -> Bool {
        guard let excluding else { return false }
        var current: Folder? = folder
        while let node = current {
            if node === excluding { return true }
            current = node.parentFolder
        }
        return false
    }
}
