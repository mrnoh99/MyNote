import SwiftUI
import SwiftData

/// 노트를 다른 노트북으로 "이동"하거나 "복제"할 때 목적지 노트북을 고르는 모달 시트.
struct NotebookPickerView: View {
    let itemTitle: String
    let excluding: Notebook?
    let onSelect: (Notebook) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Notebook.title) private var allNotebooks: [Notebook]

    private var notebooks: [Notebook] {
        allNotebooks.filter { $0 != excluding }
    }

    var body: some View {
        NavigationStack {
            List(notebooks) { notebook in
                Button {
                    onSelect(notebook)
                    dismiss()
                } label: {
                    Label(notebook.title, systemImage: "book.closed")
                }
            }
            .navigationTitle("\"\(itemTitle)\" 대상 노트북")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .overlay {
                if notebooks.isEmpty {
                    ContentUnavailableView(
                        "이동할 노트북이 없습니다",
                        systemImage: "book.closed",
                        description: Text("다른 노트북을 먼저 만드세요")
                    )
                }
            }
        }
    }
}
