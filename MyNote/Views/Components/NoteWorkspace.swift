import SwiftUI

/// 앱 전체에서 공유되는 "열린 노트" 상태(브라우저 탭과 비슷하게 동작).
/// `RootView`가 이 객체를 하나만 만들어서 사이드바 탐색과 무관하게
/// 유지하므로, 다른 노트북으로 이동해도 열려 있던 탭은 그대로 남는다.
final class NoteWorkspace: ObservableObject {
    @Published var openNotes: [Note] = []
    @Published var activeNote: Note?

    func open(_ note: Note) {
        if !openNotes.contains(note) {
            openNotes.append(note)
        }
        activeNote = note
    }

    /// 탭을 닫는다. 노트 자체를 지우지는 않는다.
    func close(_ note: Note) {
        openNotes.removeAll { $0 == note }
        if activeNote == note {
            activeNote = openNotes.last
        }
    }

    func closeAll() {
        openNotes.removeAll()
        activeNote = nil
    }
}

/// 화면 위쪽에 고정으로 떠서 열려 있는 노트들을 브라우저 탭처럼 보여준다.
/// 탭을 탭하면 전환, ×로 닫기, +로 노트 목록으로 돌아가 다른 노트를 연다.
struct NoteTabBarView: View {
    @ObservedObject var workspace: NoteWorkspace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(workspace.openNotes) { note in
                    tabChip(note)
                }
                Button {
                    workspace.activeNote = nil
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
        let isActive = workspace.activeNote == note
        return HStack(spacing: 6) {
            Image(systemName: note.kind == .pdf ? "doc.richtext" : "pencil.and.scribble")
                .font(.caption)
            Text(note.title)
                .font(.caption)
                .lineLimit(1)
            Button {
                workspace.close(note)
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
            workspace.activeNote = note
        }
    }
}
