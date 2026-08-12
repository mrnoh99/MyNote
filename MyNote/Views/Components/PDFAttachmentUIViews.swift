import UIKit

/// PDF 페이지 컨테이너(줌 대상 뷰) 안에 직접 얹는 이미지 첨부. SwiftUI가
/// 아니라 순수 UIKit으로 구현한 이유는, 이 뷰가 바깥쪽 UIScrollView가
/// 확대/축소하는 컨테이너의 자식으로 들어가야 페이지와 같이 확대되기
/// 때문이다(SwiftUI를 UIHostingController로 끼워 넣는 것보다 제스처
/// 충돌을 다루기가 훨씬 단순하다). "편집 모드"일 때만 드래그/리사이즈/
/// 삭제 제스처가 활성화되고, 편집 모드가 아닐 때는 그냥 정적인 이미지로
/// 보인다 — 그래야 평소에는 손가락이 페이지 확대/축소·이동에만 쓰인다.
final class PDFImageAttachmentUIView: UIView {
    let attachment: ImageAttachment
    private let onDelete: () -> Void
    private let onPositionChanged: () -> Void
    private let onSizeChanged: () -> Void

    private let imageView = UIImageView()
    private let deleteButton = UIButton(type: .system)
    private let resizeHandle = UIView()

    private var panGesture: UIPanGestureRecognizer!
    private var resizePanGesture: UIPanGestureRecognizer!

    private var dragStartCenter: CGPoint = .zero
    private var resizeStartSize: CGSize = .zero

    init(
        attachment: ImageAttachment,
        onDelete: @escaping () -> Void,
        onPositionChanged: @escaping () -> Void,
        onSizeChanged: @escaping () -> Void
    ) {
        self.attachment = attachment
        self.onDelete = onDelete
        self.onPositionChanged = onPositionChanged
        self.onSizeChanged = onSizeChanged
        super.init(frame: .zero)
        setupViews()
        applyModelFrame()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = attachment.imageData.flatMap { UIImage(data: $0) }
        addSubview(imageView)

        layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.5).cgColor

        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.backgroundColor = .white
        deleteButton.layer.cornerRadius = 11
        deleteButton.clipsToBounds = true
        deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)
        addSubview(deleteButton)

        resizeHandle.backgroundColor = .white
        resizeHandle.layer.cornerRadius = 11
        let resizeIcon = UIImageView(image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"))
        resizeIcon.tintColor = .systemBlue
        resizeIcon.contentMode = .center
        resizeHandle.addSubview(resizeIcon)
        addSubview(resizeHandle)

        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)

        resizePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        resizeHandle.addGestureRecognizer(resizePanGesture)

        setEditingEnabled(false)
    }

    func applyModelFrame() {
        frame = CGRect(x: attachment.positionX, y: attachment.positionY, width: attachment.width, height: attachment.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        deleteButton.frame = CGRect(x: bounds.width - 14, y: -8, width: 22, height: 22)
        resizeHandle.frame = CGRect(x: bounds.width - 14, y: bounds.height - 14, width: 22, height: 22)
        resizeHandle.subviews.first?.frame = resizeHandle.bounds
    }

    func setEditingEnabled(_ enabled: Bool) {
        panGesture.isEnabled = enabled
        resizePanGesture.isEnabled = enabled
        deleteButton.isHidden = !enabled
        resizeHandle.isHidden = !enabled
        layer.borderWidth = enabled ? 1 : 0
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview else { return }
        switch gesture.state {
        case .began:
            dragStartCenter = center
        case .changed:
            let translation = gesture.translation(in: superview)
            center = CGPoint(x: dragStartCenter.x + translation.x, y: dragStartCenter.y + translation.y)
        case .ended, .cancelled:
            attachment.positionX = frame.origin.x
            attachment.positionY = frame.origin.y
            onPositionChanged()
        default:
            break
        }
    }

    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            resizeStartSize = bounds.size
        case .changed:
            let translation = gesture.translation(in: self)
            let newWidth = max(48, resizeStartSize.width + translation.x)
            let newHeight = max(48, resizeStartSize.height + translation.y)
            frame.size = CGSize(width: newWidth, height: newHeight)
        case .ended, .cancelled:
            attachment.width = bounds.width
            attachment.height = bounds.height
            onSizeChanged()
        default:
            break
        }
    }

    @objc private func handleDeleteTap() {
        onDelete()
    }
}

/// PDF 페이지 컨테이너 안에 직접 얹는 텍스트 상자. 이미지와 달리 본문이
/// `UITextView`라서 몸통 전체에 드래그 제스처를 달면 텍스트 커서 이동과
/// 충돌하므로, 위쪽 작은 막대(드래그 손잡이)로만 이동시킨다.
final class PDFTextBoxAttachmentUIView: UIView {
    let attachment: TextBoxAttachment
    private let onDelete: () -> Void
    private let onPositionChanged: () -> Void
    private let onSizeChanged: () -> Void
    private let onTextChanged: () -> Void

    private let textView = UITextView()
    private let dragHandle = UIView()
    private let deleteButton = UIButton(type: .system)
    private let resizeHandle = UIView()

    private var panGesture: UIPanGestureRecognizer!
    private var resizePanGesture: UIPanGestureRecognizer!

    private var dragStartCenter: CGPoint = .zero
    private var resizeStartSize: CGSize = .zero

    init(
        attachment: TextBoxAttachment,
        onDelete: @escaping () -> Void,
        onPositionChanged: @escaping () -> Void,
        onSizeChanged: @escaping () -> Void,
        onTextChanged: @escaping () -> Void
    ) {
        self.attachment = attachment
        self.onDelete = onDelete
        self.onPositionChanged = onPositionChanged
        self.onSizeChanged = onSizeChanged
        self.onTextChanged = onTextChanged
        super.init(frame: .zero)
        setupViews()
        applyModelFrame()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
        layer.cornerRadius = 6
        layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.5).cgColor

        textView.text = attachment.text
        textView.font = .systemFont(ofSize: attachment.fontSize)
        textView.textColor = UIColor(hex: attachment.colorHex) ?? .label
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.delegate = self
        addSubview(textView)

        dragHandle.backgroundColor = .systemGray4
        dragHandle.layer.cornerRadius = 2
        addSubview(dragHandle)

        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.backgroundColor = .white
        deleteButton.layer.cornerRadius = 11
        deleteButton.clipsToBounds = true
        deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)
        addSubview(deleteButton)

        resizeHandle.backgroundColor = .white
        resizeHandle.layer.cornerRadius = 11
        let resizeIcon = UIImageView(image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"))
        resizeIcon.tintColor = .systemBlue
        resizeIcon.contentMode = .center
        resizeHandle.addSubview(resizeIcon)
        addSubview(resizeHandle)

        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        dragHandle.addGestureRecognizer(panGesture)

        resizePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        resizeHandle.addGestureRecognizer(resizePanGesture)

        setEditingEnabled(false)
    }

    func applyModelFrame() {
        frame = CGRect(x: attachment.positionX, y: attachment.positionY, width: attachment.width, height: attachment.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let handleAreaHeight: CGFloat = 18
        dragHandle.frame = CGRect(x: bounds.width / 2 - 20, y: 4, width: 40, height: 4)
        textView.frame = CGRect(x: 4, y: handleAreaHeight, width: bounds.width - 8, height: bounds.height - handleAreaHeight - 4)
        deleteButton.frame = CGRect(x: bounds.width - 14, y: -8, width: 22, height: 22)
        resizeHandle.frame = CGRect(x: bounds.width - 14, y: bounds.height - 14, width: 22, height: 22)
        resizeHandle.subviews.first?.frame = resizeHandle.bounds
    }

    func setEditingEnabled(_ enabled: Bool) {
        panGesture.isEnabled = enabled
        resizePanGesture.isEnabled = enabled
        deleteButton.isHidden = !enabled
        resizeHandle.isHidden = !enabled
        dragHandle.isHidden = !enabled
        textView.isEditable = enabled
        layer.borderWidth = enabled ? 1 : 0
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview else { return }
        switch gesture.state {
        case .began:
            dragStartCenter = center
        case .changed:
            let translation = gesture.translation(in: superview)
            center = CGPoint(x: dragStartCenter.x + translation.x, y: dragStartCenter.y + translation.y)
        case .ended, .cancelled:
            attachment.positionX = frame.origin.x
            attachment.positionY = frame.origin.y
            onPositionChanged()
        default:
            break
        }
    }

    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            resizeStartSize = bounds.size
        case .changed:
            let translation = gesture.translation(in: self)
            let newWidth = max(80, resizeStartSize.width + translation.x)
            let newHeight = max(44, resizeStartSize.height + translation.y)
            frame.size = CGSize(width: newWidth, height: newHeight)
        case .ended, .cancelled:
            attachment.width = bounds.width
            attachment.height = bounds.height
            onSizeChanged()
        default:
            break
        }
    }

    @objc private func handleDeleteTap() {
        onDelete()
    }
}

extension PDFTextBoxAttachmentUIView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        attachment.text = textView.text
        onTextChanged()
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
