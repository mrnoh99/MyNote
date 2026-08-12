import SwiftUI
import SwiftData
import PDFKit
import PencilKit
import PhotosUI

struct PDFAnnotationView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext

    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex = 0
    @State private var pageCount = 0
    @State private var canvasView = PKCanvasView()
    @State private var zoomController = PDFZoomController()
    @StateObject private var toolState = PencilToolState()
    @State private var undoStateTick = 0
    @State private var isShowingShareSheet = false
    @State private var shareURL: URL?
    @State private var loadErrorMessage: String?
    @State private var exportErrorMessage: String?
    @State private var isShowingAudioSheet = false
    @State private var isEditingAttachments = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    /// 현재 페이지에 속한 첨부만 걸러서 읽는다. 이 계산 프로퍼티를 body에서
    /// 직접 참조해야 SwiftUI Observation이 `note.imageAttachments`의
    /// 변화를 추적해서 화면을 다시 그린다.
    private var currentPageImageAttachments: [ImageAttachment] {
        (note.imageAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
    }

    private var currentPageTextBoxAttachments: [TextBoxAttachment] {
        (note.textBoxAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
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

            if let pdfDocument {
                GeometryReader { geometry in
                    ZoomablePDFPageView(
                        document: pdfDocument,
                        pageIndex: currentPageIndex,
                        imageAttachments: currentPageImageAttachments,
                        textBoxAttachments: currentPageTextBoxAttachments,
                        canvasView: $canvasView,
                        drawingData: annotationData(for: currentPageIndex),
                        controller: zoomController,
                        toolState: toolState,
                        viewportSize: geometry.size,
                        isEditingAttachments: isEditingAttachments,
                        modelContext: modelContext
                    ) { drawing in
                        saveAnnotation(drawing, forPage: currentPageIndex)
                        undoStateTick += 1
                    }
                }
                pageNavigationBar
            } else if let loadErrorMessage {
                ContentUnavailableView("PDF를 열 수 없습니다", systemImage: "exclamationmark.triangle", description: Text(loadErrorMessage))
            } else {
                ProgressView("PDF 불러오는 중...")
            }
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("제목", text: $note.title)
                    .multilineTextAlignment(.center)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    zoomController.fitToScreen()
                } label: {
                    Label("화면에 맞추기", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .disabled(pdfDocument == nil || isEditingAttachments)
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
                .disabled(pdfDocument == nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("이미지 추가", systemImage: "photo.badge.plus")
                }
                .disabled(pdfDocument == nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    addTextBox()
                } label: {
                    Label("텍스트 상자 추가", systemImage: "textbox")
                }
                .disabled(pdfDocument == nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    exportAndShare()
                } label: {
                    Label("내보내기", systemImage: "square.and.arrow.up")
                }
                .disabled(pdfDocument == nil)
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
        .sheet(isPresented: $isShowingShareSheet) {
            if let shareURL {
                ActivityView(activityItems: [shareURL])
            }
        }
        .sheet(isPresented: $isShowingAudioSheet) {
            AudioRecordingsSheet(note: note)
        }
        .alert(
            "내보내기 실패",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button("확인") { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .task {
            loadDocument()
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
        }
        .padding()
        .background(.bar)
    }

    private func loadDocument() {
        guard let data = note.pdfData else {
            loadErrorMessage = "이 노트에 저장된 PDF 데이터가 없습니다."
            return
        }
        guard let document = PDFDocument(data: data) else {
            loadErrorMessage = "PDF 파일 형식을 인식할 수 없습니다."
            return
        }
        pdfDocument = document
        pageCount = document.pageCount
    }

    private func annotationData(for pageIndex: Int) -> Data? {
        (note.pdfAnnotations ?? []).first { $0.pageIndex == pageIndex }?.drawingData
    }

    private func saveAnnotation(_ drawing: PKDrawing, forPage pageIndex: Int) {
        if let existing = (note.pdfAnnotations ?? []).first(where: { $0.pageIndex == pageIndex }) {
            existing.drawingData = drawing.dataRepresentation()
        } else {
            let annotation = PDFPageAnnotation(pageIndex: pageIndex, drawingData: drawing.dataRepresentation())
            annotation.note = note
            modelContext.insert(annotation)
        }
        note.updatedAt = .now
    }

    private func goToPage(_ index: Int) {
        guard index >= 0, index < pageCount else { return }
        currentPageIndex = index
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

    private func exportAndShare() {
        guard let pdfData = note.pdfData,
              let flattened = PDFAnnotationFlattener.flatten(pdfData: pdfData, annotations: note.pdfAnnotations ?? []) else {
            return
        }
        let fileName = note.title.isEmpty ? "MyNote" : note.title
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).pdf")
        do {
            try flattened.write(to: url, options: .atomic)
            shareURL = url
            isShowingShareSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}
