import SwiftUI
import PencilKit

struct NoteEditorView: View {
    @Bindable var note: Note
    @State private var canvasView = PKCanvasView()

    var body: some View {
        ZStack {
            NotePaperBackgroundView(style: note.backgroundStyle)
                .ignoresSafeArea()

            CanvasRepresentable(
                canvasView: $canvasView,
                initialDrawingData: note.drawingData
            ) { drawing in
                note.drawingData = drawing.dataRepresentation()
                note.updatedAt = .now
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
