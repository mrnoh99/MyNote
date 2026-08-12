import SwiftUI
import PDFKit
import PencilKit

/// PDF 페이지의 확대/축소/이동을 제어하는 리모컨. SwiftUI 쪽에서
/// `controller.fitToScreen()`을 호출하면 현재 페이지가 화면에 맞는
/// 배율로 즉시 되돌아온다.
final class PDFZoomController {
    fileprivate var resetToFitAction: (() -> Void)?

    func fitToScreen() {
        resetToFitAction?()
    }
}

/// PDF 페이지를 확대·축소·이동하면서 그 위에 애플펜슬 전용 필기
/// 레이어를 겹쳐 보여준다. 손가락(핀치/드래그)은 화면 확대·이동을,
/// 애플펜슬은 필기를 담당하도록 입력을 나눴다. 페이지 이미지와 필기
/// 레이어를 같은 컨테이너 뷰 안에 넣고 바깥쪽 UIScrollView 하나로만
/// 확대/축소하기 때문에, 확대해도 필기와 PDF가 항상 같은 자리에 맞춰
/// 보인다.
struct ZoomablePDFPageView: UIViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int
    @Binding var canvasView: PKCanvasView
    var drawingData: Data?
    var controller: PDFZoomController
    var viewportSize: CGSize
    var onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .secondarySystemBackground
        scrollView.delegate = context.coordinator

        let containerView = UIView()
        containerView.backgroundColor = .clear
        scrollView.addSubview(containerView)

        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        containerView.addSubview(imageView)

        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled = false
        canvasView.delegate = context.coordinator
        containerView.addSubview(canvasView)

        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = containerView
        context.coordinator.imageView = imageView
        context.coordinator.canvasView = canvasView

        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        context.coordinator.toolPicker = toolPicker

        controller.resetToFitAction = { [weak coordinator = context.coordinator] in
            coordinator?.fitToScreen(animated: true)
        }

        context.coordinator.reloadPage(document: document, pageIndex: pageIndex, viewportSize: viewportSize)
        context.coordinator.reloadDrawing(drawingData)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onDrawingChanged = onDrawingChanged

        let pageChanged = context.coordinator.loadedPageIndex != pageIndex
        let viewportChanged = context.coordinator.lastViewportSize != viewportSize

        guard pageChanged || viewportChanged else { return }

        context.coordinator.reloadPage(document: document, pageIndex: pageIndex, viewportSize: viewportSize)
        if pageChanged {
            context.coordinator.reloadDrawing(drawingData)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        weak var scrollView: UIScrollView?
        weak var containerView: UIView?
        weak var imageView: UIImageView?
        weak var canvasView: PKCanvasView?
        var toolPicker: PKToolPicker?

        var loadedPageIndex: Int = -1
        var lastViewportSize: CGSize = .zero
        var onDrawingChanged: (PKDrawing) -> Void

        init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            containerView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContainer()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged(canvasView.drawing)
        }

        func reloadPage(document: PDFDocument, pageIndex: Int, viewportSize: CGSize) {
            guard viewportSize.width > 0, viewportSize.height > 0,
                  let page = document.page(at: pageIndex) else { return }

            let pageBounds = page.bounds(for: .mediaBox)
            loadedPageIndex = pageIndex
            lastViewportSize = viewportSize

            let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
            let image = renderer.image { rendererContext in
                UIColor.white.setFill()
                rendererContext.fill(CGRect(origin: .zero, size: pageBounds.size))
                let cgContext = rendererContext.cgContext
                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageBounds.height)
                cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()
            }

            containerView?.frame = CGRect(origin: .zero, size: pageBounds.size)
            imageView?.frame = CGRect(origin: .zero, size: pageBounds.size)
            imageView?.image = image
            canvasView?.frame = CGRect(origin: .zero, size: pageBounds.size)
            scrollView?.contentSize = pageBounds.size

            let fitScale = min(viewportSize.width / pageBounds.width, viewportSize.height / pageBounds.height)
            guard fitScale > 0 else { return }
            scrollView?.minimumZoomScale = fitScale
            scrollView?.maximumZoomScale = fitScale * 5
            scrollView?.zoomScale = fitScale
            centerContainer()
        }

        func reloadDrawing(_ data: Data?) {
            guard let canvasView else { return }
            if let data, let drawing = try? PKDrawing(data: data) {
                canvasView.drawing = drawing
            } else {
                canvasView.drawing = PKDrawing()
            }
        }

        func fitToScreen(animated: Bool) {
            guard let scrollView else { return }
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: animated)
            centerContainer()
        }

        private func centerContainer() {
            guard let scrollView, let containerView else { return }
            let boundsSize = scrollView.bounds.size
            var frame = containerView.frame
            frame.origin.x = frame.width < boundsSize.width ? (boundsSize.width - frame.width) / 2 : 0
            frame.origin.y = frame.height < boundsSize.height ? (boundsSize.height - frame.height) / 2 : 0
            containerView.frame = frame
        }
    }
}
