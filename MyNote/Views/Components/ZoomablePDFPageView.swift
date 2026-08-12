import SwiftUI
import SwiftData
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
/// 레이어, 그리고 이미지/텍스트 상자 첨부를 겹쳐 보여준다.
///
/// 입력은 세 갈래로 나뉜다:
/// - 손가락(핀치/드래그): 페이지 확대·축소·이동 (첨부물 편집 모드가
///   아닐 때만)
/// - 애플펜슬: 필기
/// - 첨부물 편집 모드가 켜져 있을 때: 손가락으로 이미지/텍스트 상자를
///   드래그·리사이즈·삭제 — 이때는 페이지 확대/축소와 필기가 잠시
///   꺼진다. 그래야 "화면 이동"과 "첨부물 이동" 제스처가 서로 다투지
///   않는다.
///
/// 페이지 이미지·필기 레이어·첨부물을 전부 같은 컨테이너 뷰 안에 넣고
/// 바깥쪽 UIScrollView 하나로만 확대/축소하기 때문에, 확대해도 전부
/// 같은 자리에 맞춰 함께 움직인다.
struct ZoomablePDFPageView: UIViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int
    /// 호출하는 쪽(PDFAnnotationView)이 현재 페이지에 해당하는 첨부만
    /// 걸러서 넘긴다 — 그래야 body에서 `note.imageAttachments`를 직접
    /// 읽어 SwiftUI Observation 의존성이 제대로 등록된다(단순히 note
    /// 객체 참조만 넘기면 배열이 바뀌어도 다시 그려지지 않을 수 있다).
    var imageAttachments: [ImageAttachment]
    var textBoxAttachments: [TextBoxAttachment]
    @Binding var canvasView: PKCanvasView
    var drawingData: Data?
    var controller: PDFZoomController
    var toolState: PencilToolState
    var viewportSize: CGSize
    var isEditingAttachments: Bool
    var modelContext: ModelContext
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
        canvasView.tool = toolState.pkTool
        containerView.addSubview(canvasView)

        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = containerView
        context.coordinator.imageView = imageView
        context.coordinator.canvasView = canvasView
        context.coordinator.modelContext = modelContext

        controller.resetToFitAction = { [weak coordinator = context.coordinator] in
            coordinator?.fitToScreen(animated: true)
        }

        context.coordinator.reloadPage(document: document, pageIndex: pageIndex, viewportSize: viewportSize)
        context.coordinator.reloadDrawing(drawingData)
        context.coordinator.syncAttachments(images: imageAttachments, textBoxes: textBoxAttachments, isEditing: isEditingAttachments)
        context.coordinator.applyEditingMode(isEditingAttachments)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onDrawingChanged = onDrawingChanged
        context.coordinator.modelContext = modelContext
        canvasView.tool = toolState.pkTool

        let pageChanged = context.coordinator.loadedPageIndex != pageIndex
        let viewportChanged = context.coordinator.lastViewportSize != viewportSize

        if pageChanged || viewportChanged {
            context.coordinator.reloadPage(document: document, pageIndex: pageIndex, viewportSize: viewportSize)
        }
        if pageChanged {
            context.coordinator.reloadDrawing(drawingData)
        }

        context.coordinator.syncAttachments(images: imageAttachments, textBoxes: textBoxAttachments, isEditing: isEditingAttachments)
        context.coordinator.applyEditingMode(isEditingAttachments)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        weak var scrollView: UIScrollView?
        weak var containerView: UIView?
        weak var imageView: UIImageView?
        weak var canvasView: PKCanvasView?
        var modelContext: ModelContext?

        var loadedPageIndex: Int = -1
        var lastViewportSize: CGSize = .zero
        var onDrawingChanged: (PKDrawing) -> Void

        private var imageAttachmentViews: [UUID: PDFImageAttachmentUIView] = [:]
        private var textBoxAttachmentViews: [UUID: PDFTextBoxAttachmentUIView] = [:]

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

        /// 편집 모드일 때는 페이지 확대/축소·이동과 필기를 잠시 끄고
        /// 첨부물 제스처만 받는다. 편집 모드가 아니면 반대.
        func applyEditingMode(_ isEditing: Bool) {
            scrollView?.pinchGestureRecognizer?.isEnabled = !isEditing
            scrollView?.panGestureRecognizer.isEnabled = !isEditing
            canvasView?.isUserInteractionEnabled = !isEditing
        }

        /// 현재 페이지에 속한 첨부물(호출하는 쪽에서 이미 페이지로 걸러서
        /// 넘김)과 화면에 이미 떠 있는 뷰를 비교해서 새로 생긴 것만
        /// 추가하고 사라진 것만 제거한다. 기존 뷰는 건드리지 않아서
        /// 사용자가 텍스트를 입력하는 도중에도 끊기지 않는다.
        func syncAttachments(images currentImages: [ImageAttachment], textBoxes currentTextBoxes: [TextBoxAttachment], isEditing: Bool) {
            guard let containerView else { return }

            let currentImageIDs = Set(currentImages.map(\.id))
            let currentTextBoxIDs = Set(currentTextBoxes.map(\.id))

            for (id, view) in imageAttachmentViews where !currentImageIDs.contains(id) {
                view.removeFromSuperview()
                imageAttachmentViews.removeValue(forKey: id)
            }
            for (id, view) in textBoxAttachmentViews where !currentTextBoxIDs.contains(id) {
                view.removeFromSuperview()
                textBoxAttachmentViews.removeValue(forKey: id)
            }

            for attachment in currentImages where imageAttachmentViews[attachment.id] == nil {
                let view = PDFImageAttachmentUIView(
                    attachment: attachment,
                    onDelete: { [weak self] in self?.deleteImageAttachment(attachment) },
                    onPositionChanged: {},
                    onSizeChanged: {}
                )
                containerView.addSubview(view)
                imageAttachmentViews[attachment.id] = view
            }
            for attachment in currentTextBoxes where textBoxAttachmentViews[attachment.id] == nil {
                let view = PDFTextBoxAttachmentUIView(
                    attachment: attachment,
                    onDelete: { [weak self] in self?.deleteTextBoxAttachment(attachment) },
                    onPositionChanged: {},
                    onSizeChanged: {},
                    onTextChanged: {}
                )
                containerView.addSubview(view)
                textBoxAttachmentViews[attachment.id] = view
            }

            for view in imageAttachmentViews.values {
                view.setEditingEnabled(isEditing)
            }
            for view in textBoxAttachmentViews.values {
                view.setEditingEnabled(isEditing)
            }
        }

        private func deleteImageAttachment(_ attachment: ImageAttachment) {
            imageAttachmentViews[attachment.id]?.removeFromSuperview()
            imageAttachmentViews.removeValue(forKey: attachment.id)
            modelContext?.delete(attachment)
        }

        private func deleteTextBoxAttachment(_ attachment: TextBoxAttachment) {
            textBoxAttachmentViews[attachment.id]?.removeFromSuperview()
            textBoxAttachmentViews.removeValue(forKey: attachment.id)
            modelContext?.delete(attachment)
        }
    }
}
