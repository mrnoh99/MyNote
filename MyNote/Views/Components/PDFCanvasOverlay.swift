import SwiftUI
import PencilKit

/// PDF 페이지 위에 겹쳐지는 애플펜슬 전용 필기 레이어.
/// pageIndex가 바뀌면 해당 페이지에 저장된 드로잉을 새로 불러온다.
struct PDFCanvasOverlay: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var pageIndex: Int
    var drawingData: Data?
    var onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator

        loadDrawing(into: canvasView, context: context)

        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        context.coordinator.toolPicker = toolPicker

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if context.coordinator.loadedPageIndex != pageIndex {
            loadDrawing(into: uiView, context: context)
        }
    }

    private func loadDrawing(into canvasView: PKCanvasView, context: Context) {
        if let drawingData, let drawing = try? PKDrawing(data: drawingData) {
            canvasView.drawing = drawing
        } else {
            canvasView.drawing = PKDrawing()
        }
        context.coordinator.loadedPageIndex = pageIndex
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var toolPicker: PKToolPicker?
        var loadedPageIndex: Int = -1
        let onDrawingChanged: (PKDrawing) -> Void

        init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged(canvasView.drawing)
        }
    }
}
