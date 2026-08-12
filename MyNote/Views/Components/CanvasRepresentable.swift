import SwiftUI
import PencilKit

/// 필기 노트 전용 캔버스. 손가락과 애플펜슬 입력을 모두 받아들인다.
struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var initialDrawingData: Data?
    var onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .systemBackground
        canvasView.delegate = context.coordinator

        if let initialDrawingData, let drawing = try? PKDrawing(data: initialDrawingData) {
            canvasView.drawing = drawing
        }

        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        context.coordinator.toolPicker = toolPicker

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var toolPicker: PKToolPicker?
        let onDrawingChanged: (PKDrawing) -> Void

        init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged(canvasView.drawing)
        }
    }
}
