import SwiftUI
import SwiftData
import PencilKit
import PhotosUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext

    @State private var canvasView = PKCanvasView()
    @StateObject private var toolState = PencilToolState()
    @State private var undoStateTick = 0
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingAudioSheet = false

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

                AttachmentOverlayView(note: note)
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
            ToolbarItem(placement: .secondaryAction) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("이미지 추가", systemImage: "photo.badge.plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    addTextBox()
                } label: {
                    Label("텍스트 상자 추가", systemImage: "textbox")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    isShowingAudioSheet = true
                } label: {
                    Label("음성 메모", systemImage: "mic")
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    addImageAttachment(data: data)
                }
                selectedPhotoItem = nil
            }
        }
        .sheet(isPresented: $isShowingAudioSheet) {
            AudioRecordingsSheet(note: note)
        }
    }

    private func addImageAttachment(data: Data) {
        let attachment = ImageAttachment(imageData: data)
        attachment.note = note
        modelContext.insert(attachment)
        note.updatedAt = .now
    }

    private func addTextBox() {
        let attachment = TextBoxAttachment(text: "")
        attachment.note = note
        modelContext.insert(attachment)
        note.updatedAt = .now
    }
}
