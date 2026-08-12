import SwiftUI
import PencilKit

struct NoteEditorView: View {
    @Bindable var note: Note
    @State private var canvasView = PKCanvasView()

    var body: some View {
        CanvasRepresentable(
            canvasView: $canvasView,
            initialDrawingData: note.drawingData
        ) { drawing in
            note.drawingData = drawing.dataRepresentation()
            note.updatedAt = .now
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
        }
    }
}
