import SwiftUI
import SwiftData
import PencilKit

/// 필기 노트 페이지의 고정 크기. PDF와 달리 원본 문서 크기가 없으므로
/// 임의의 "종이" 크기를 정해서 쓴다.
enum NotePageGeometry {
    static let size = CGSize(width: 834, height: 1194)
}

/// 필기 노트 페이지의 확대/축소/이동을 제어하는 리모컨.
final class NotePageZoomController {
    fileprivate var resetToFitAction: (() -> Void)?

    func fitToScreen() {
        resetToFitAction?()
    }
}

/// 종이 배경을 직접 그리는 UIKit 뷰. SwiftUI `NotePaperBackgroundView`와
/// 같은 무늬를 그리지만, 확대/축소되는 UIScrollView 컨테이너 안에 다른
/// 서브뷰(캔버스, 첨부물)와 함께 얹을 수 있도록 순수 UIKit으로 만들었다.
final class NotePaperBackgroundUIView: UIView {
    var style: NoteBackgroundStyle = .blank {
        didSet { setNeedsDisplay() }
    }

    private let paperColor = UIColor(red: 0.973, green: 0.965, blue: 0.933, alpha: 1)
    private let ruleLineColor = UIColor(red: 0.72, green: 0.74, blue: 0.7, alpha: 1)
    private let marginLineColor = UIColor(red: 0.82, green: 0.36, blue: 0.36, alpha: 1)
    private let staffLineColor = UIColor(red: 0.35, green: 0.35, blue: 0.4, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let bounds = self.bounds

        paperColor.setFill()
        ctx.fill(bounds)

        switch style {
        case .blank:
            break

        case .lined:
            ruleLineColor.setStroke()
            ctx.setLineWidth(1)
            var y: CGFloat = 40
            while y < bounds.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: bounds.width, y: y))
                y += 40
            }
            ctx.strokePath()

            marginLineColor.setStroke()
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 70, y: 0))
            ctx.addLine(to: CGPoint(x: 70, y: bounds.height))
            ctx.strokePath()

        case .dotGrid:
            ruleLineColor.setFill()
            let spacing: CGFloat = 32
            let dotRadius: CGFloat = 1.6
            var y: CGFloat = spacing
            while y < bounds.height {
                var x: CGFloat = spacing
                while x < bounds.width {
                    let dotRect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    ctx.fillEllipse(in: dotRect)
                    x += spacing
                }
                y += spacing
            }

        case .squareGrid:
            ruleLineColor.setStroke()
            ctx.setLineWidth(0.75)
            let spacing: CGFloat = 32
            var x: CGFloat = spacing
            while x < bounds.width {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: bounds.height))
                x += spacing
            }
            var y: CGFloat = spacing
            while y < bounds.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: bounds.width, y: y))
                y += spacing
            }
            ctx.strokePath()

        case .staffPaper:
            staffLineColor.setStroke()
            ctx.setLineWidth(1)
            let lineSpacing: CGFloat = 10
            let groupSpacing: CGFloat = 70
            let sideMargin: CGFloat = 30
            var top: CGFloat = 50
            while top < bounds.height {
                for lineIndex in 0..<5 {
                    let y = top + CGFloat(lineIndex) * lineSpacing
                    ctx.move(to: CGPoint(x: sideMargin, y: y))
                    ctx.addLine(to: CGPoint(x: bounds.width - sideMargin, y: y))
                }
                top += groupSpacing
            }
            ctx.strokePath()
        }
    }
}

/// 필기 노트 한 페이지를 확대·축소·이동하면서 그 위에 애플펜슬 전용
/// 필기 레이어, 그리고 이미지/텍스트 상자 첨부를 겹쳐 보여준다.
/// 구조와 입력 규칙은 `ZoomablePDFPageView`와 동일하다 — 손가락은 페이지
/// 확대·축소·이동(첨부물 편집 모드가 아닐 때), 애플펜슬은 필기,
/// 첨부물 편집 모드에서는 손가락으로 첨부물을 드래그·리사이즈·삭제한다.
struct ZoomableNotePageView: UIViewRepresentable {
    let backgroundStyle: NoteBackgroundStyle
    @Binding var canvasView: PKCanvasView
    var drawingData: Data?
    var controller: NotePageZoomController
    var toolState: PencilToolState
    var viewportSize: CGSize
    var imageAttachments: [ImageAttachment]
    var textBoxAttachments: [TextBoxAttachment]
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

        let backgroundView = NotePaperBackgroundUIView()
        containerView.addSubview(backgroundView)

        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled = false
        canvasView.delegate = context.coordinator
        canvasView.tool = toolState.pkTool
        containerView.addSubview(canvasView)

        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = containerView
        context.coordinator.backgroundView = backgroundView
        context.coordinator.canvasView = canvasView
        context.coordinator.modelContext = modelContext

        controller.resetToFitAction = { [weak coordinator = context.coordinator] in
            coordinator?.fitToScreen(animated: true)
        }

        context.coordinator.setupPage(backgroundStyle: backgroundStyle, viewportSize: viewportSize)
        context.coordinator.reloadDrawing(drawingData)
        context.coordinator.syncAttachments(images: imageAttachments, textBoxes: textBoxAttachments, isEditing: isEditingAttachments)
        context.coordinator.applyEditingMode(isEditingAttachments)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onDrawingChanged = onDrawingChanged
        context.coordinator.modelContext = modelContext
        canvasView.tool = toolState.pkTool

        let viewportChanged = context.coordinator.lastViewportSize != viewportSize
        if viewportChanged {
            context.coordinator.setupPage(backgroundStyle: backgroundStyle, viewportSize: viewportSize)
        }
        if context.coordinator.backgroundView?.style != backgroundStyle {
            context.coordinator.backgroundView?.style = backgroundStyle
        }

        // drawingData가 바뀌었다는 건 페이지를 전환했다는 뜻이다(같은
        // 페이지 안에서는 캔버스가 직접 그리므로 이 값이 바뀌지 않는다).
        if context.coordinator.currentDrawingData != drawingData {
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
        weak var backgroundView: NotePaperBackgroundUIView?
        weak var canvasView: PKCanvasView?
        var modelContext: ModelContext?

        var lastViewportSize: CGSize = .zero
        var currentDrawingData: Data?
        var onDrawingChanged: (PKDrawing) -> Void

        private var imageAttachmentViews: [UUID: PageImageAttachmentUIView] = [:]
        private var textBoxAttachmentViews: [UUID: PageTextBoxAttachmentUIView] = [:]

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
            currentDrawingData = canvasView.drawing.dataRepresentation()
            onDrawingChanged(canvasView.drawing)
        }

        func setupPage(backgroundStyle: NoteBackgroundStyle, viewportSize: CGSize) {
            guard viewportSize.width > 0, viewportSize.height > 0 else { return }
            lastViewportSize = viewportSize

            let pageSize = NotePageGeometry.size
            containerView?.frame = CGRect(origin: .zero, size: pageSize)
            backgroundView?.frame = CGRect(origin: .zero, size: pageSize)
            backgroundView?.style = backgroundStyle
            canvasView?.frame = CGRect(origin: .zero, size: pageSize)
            scrollView?.contentSize = pageSize

            let fitScale = min(viewportSize.width / pageSize.width, viewportSize.height / pageSize.height)
            guard fitScale > 0 else { return }
            scrollView?.minimumZoomScale = fitScale
            scrollView?.maximumZoomScale = fitScale * 5
            scrollView?.zoomScale = fitScale
            centerContainer()
        }

        func reloadDrawing(_ data: Data?) {
            guard let canvasView else { return }
            currentDrawingData = data
            if let data, let drawing = try? PKDrawing(data: data) {
                canvasView.drawing = drawing
            } else {
                canvasView.drawing = PKDrawing()
            }
            // 페이지를 바꿀 때 이전 페이지의 실행 취소 기록이 남아있으면
            // 혼란스러우므로, 페이지마다 실행 취소 기록을 새로 시작한다.
            canvasView.undoManager?.removeAllActions()
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

        func applyEditingMode(_ isEditing: Bool) {
            scrollView?.pinchGestureRecognizer?.isEnabled = !isEditing
            scrollView?.panGestureRecognizer.isEnabled = !isEditing
            canvasView?.isUserInteractionEnabled = !isEditing
        }

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
                let view = PageImageAttachmentUIView(
                    attachment: attachment,
                    onDelete: { [weak self] in self?.deleteImageAttachment(attachment) },
                    onPositionChanged: {},
                    onSizeChanged: {}
                )
                containerView.addSubview(view)
                imageAttachmentViews[attachment.id] = view
            }
            for attachment in currentTextBoxes where textBoxAttachmentViews[attachment.id] == nil {
                let view = PageTextBoxAttachmentUIView(
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
