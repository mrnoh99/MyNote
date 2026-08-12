import SwiftUI
import PencilKit

struct NoteEditorView: View {
    @Bindable var note: Note
    @State private var canvasView = PKCanvasView()
    @StateObject private var toolState = PencilToolState()
    @State private var undoStateTick = 0

    var body: some View {
        VStack(spacing: 0) {
            PencilToolbarView(
                toolState: toolState,
                canUndo: canvasView.undoManager?.canUndo ?? false,
                canRedo: canvasView.undoManager?.canRedo ?? false,
                onUndo: {
                    canvasView.undoManager?.undo()
                    undoStateTick += 1
                },
                onRedo: {
                    canvasView.undoManager?.redo()
                    undoStateTick += 1
                }
            )

            ZStack {
                NotePaperBackgroundView(style: note.backgroundStyle)
                    .ignoresSafeArea()

                CanvasRepresentable(
                    canvasView: $canvasView,
                    initialDrawingData: note.drawingData,
                    toolState: toolState
                ) { drawing in
                    note.drawingData = drawing.dataRepresentation()
                    note.updatedAt = .now
                    undoStateTick += 1
                }
            }
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("제목", text: $note.title)
                    .multilineTextAlignment(.center)
                    .onSubmit {
                        note.updatedAt = .now
                    }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    ForEach(NoteBackgroundStyle.allCases, id: \.self) { style in
                        Button {
                            note.backgroundStyle = style
                            note.updatedAt = .now
                        } label: {
                            Label(style.displayName, systemImage: style.systemImage)
                            if note.backgroundStyle == style {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Label("배경", systemImage: "doc.plaintext")
                }
            }
        }
    }
}
