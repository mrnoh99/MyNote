import SwiftUI
import SwiftData
import PencilKit
import PhotosUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext

    @State private var currentPageIndex = 0
    @State private var canvasView = PKCanvasView()
    @State private var zoomController = NotePageZoomController()
    @StateObject private var toolState = PencilToolState()
    @State private var undoStateTick = 0
    @State private var isShowingAudioSheet = false
    @State private var isEditingAttachments = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    /// `note.pages`를 body에서 직접 읽어야 SwiftUI Observation이 페이지
    /// 추가/삭제를 추적해서 화면을 다시 그린다.
    private var sortedPages: [NotePage] {
        (note.pages ?? []).sorted { $0.pageIndex < $1.pageIndex }
    }

    private var pageCount: Int { sortedPages.count }

    private var currentPage: NotePage? {
        sortedPages.first { $0.pageIndex == currentPageIndex }
    }

    /// 페이지 개념 도입 이전의 첨부물은 `pageIndex`가 nil이었다 —
    /// 그런 첨부물은 0번 페이지에 속한 것으로 취급한다.
    private var currentPageImageAttachments: [ImageAttachment] {
        (note.imageAttachments ?? []).filter { ($0.pageIndex ?? 0) == currentPageIndex }
    }

    private var currentPageTextBoxAttachments: [TextBoxAttachment] {
        (note.textBoxAttachments ?? []).filter { ($0.pageIndex ?? 0) == currentPageIndex }
    }

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

            GeometryReader { geometry in
                ZoomableNotePageView(
                    backgroundStyle: note.backgroundStyle,
                    canvasView: $canvasView,
                    drawingData: currentPage?.drawingData,
                    controller: zoomController,
                    toolState: toolState,
                    viewportSize: geometry.size,
                    imageAttachments: currentPageImageAttachments,
                    textBoxAttachments: currentPageTextBoxAttachments,
                    isEditingAttachments: isEditingAttachments,
                    modelContext: modelContext
                ) { drawing in
                    saveDrawing(drawing, forPage: currentPageIndex)
                    undoStateTick += 1
                }
            }
            pageNavigationBar
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
                Button {
                    zoomController.fitToScreen()
                } label: {
                    Label("화면에 맞추기", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .disabled(isEditingAttachments)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    isEditingAttachments.toggle()
                } label: {
                    Label(
                        isEditingAttachments ? "첨부물 편집 완료" : "첨부물 편집",
                        systemImage: isEditingAttachments ? "checkmark.circle.fill" : "photo.on.rectangle.angled"
                    )
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
        .task {
            migrateLegacyDrawingIfNeeded()
        }
    }

    private var pageNavigationBar: some View {
        HStack {
            Button {
                goToPage(currentPageIndex - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPageIndex == 0 || isEditingAttachments)

            Spacer()

            Text("\(currentPageIndex + 1) / \(pageCount)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                goToPage(currentPageIndex + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPageIndex >= pageCount - 1 || isEditingAttachments)

            Divider().frame(height: 16)

            Button {
                addPage()
            } label: {
                Label("페이지 추가", systemImage: "plus.square")
            }
            .disabled(isEditingAttachments)
        }
        .padding()
        .background(.bar)
    }

    /// 여러 페이지 도입 이전에 만들어진 노트는 `note.drawingData`에 그림이
    /// 남아있다. 처음 열 때 그 내용을 0번 페이지로 옮기고, 페이지가 하나도
    /// 없는 새 노트라면 빈 0번 페이지를 만들어준다.
    private func migrateLegacyDrawingIfNeeded() {
        guard note.pages?.isEmpty ?? true else { return }
        let firstPage = NotePage(pageIndex: 0, drawingData: note.drawingData)
        firstPage.note = note
        modelContext.insert(firstPage)
        note.drawingData = nil
    }

    private func saveDrawing(_ drawing: PKDrawing, forPage pageIndex: Int) {
        guard let page = sortedPages.first(where: { $0.pageIndex == pageIndex }) else { return }
        page.drawingData = drawing.dataRepresentation()
        note.updatedAt = .now
    }

    private func goToPage(_ index: Int) {
        guard index >= 0, index < pageCount else { return }
        currentPageIndex = index
    }

    private func addPage() {
        let newIndex = pageCount
        let page = NotePage(pageIndex: newIndex)
        page.note = note
        modelContext.insert(page)
        note.updatedAt = .now
        currentPageIndex = newIndex
    }

    private func addImageAttachment(data: Data) {
        let attachment = ImageAttachment(imageData: data, pageIndex: currentPageIndex)
        attachment.note = note
        modelContext.insert(attachment)
        note.updatedAt = .now
        isEditingAttachments = true
    }

    private func addTextBox() {
        let attachment = TextBoxAttachment(text: "", pageIndex: currentPageIndex)
        attachment.note = note
        modelContext.insert(attachment)
        note.updatedAt = .now
        isEditingAttachments = true
    }
}
