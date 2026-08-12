import SwiftUI
import PencilKit

/// 필기 노트 전용 캔버스. 손가락과 애플펜슬 입력을 모두 받아들이고,
/// 현재 도구는 iOS 기본 도구 모음이 아니라 `PencilToolbarView`가 제어하는
/// `PencilToolState`를 그대로 반영한다.
struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var initialDrawingData: Data?
    var toolState: PencilToolState
    var onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        canvasView.tool = toolState.pkTool

        if let initialDrawingData, let drawing = try? PKDrawing(data: initialDrawingData) {
            canvasView.drawing = drawing
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = toolState.pkTool
        context.coordinator.onDrawingChanged = onDrawingChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onDrawingChanged: (PKDrawing) -> Void

        init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged(canvasView.drawing)
        }
    }
}
