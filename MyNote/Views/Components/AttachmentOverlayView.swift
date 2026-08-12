import SwiftUI
import SwiftData

/// 필기 캔버스 위에 이미지/텍스트 상자를 자유롭게 배치하는 오버레이.
/// 이 뷰 자체에는 배경/제스처를 붙이지 않는다 — 그래야 첨부물이 없는
/// 빈 영역의 터치가 아래쪽 PencilKit 캔버스로 그대로 전달되어 필기가
/// 막히지 않는다.
struct AttachmentOverlayView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach((note.imageAttachments ?? []).filter { $0.pageIndex == nil }) { attachment in
                ImageAttachmentView(attachment: attachment) {
                    modelContext.delete(attachment)
                    note.updatedAt = .now
                }
            }
            ForEach((note.textBoxAttachments ?? []).filter { $0.pageIndex == nil }) { attachment in
                TextBoxAttachmentView(attachment: attachment) {
                    modelContext.delete(attachment)
                    note.updatedAt = .now
                }
            }
        }
    }
}

/// 드래그로 옮기고 모서리 손잡이로 크기를 조절할 수 있는 이미지.
struct ImageAttachmentView: View {
    @Bindable var attachment: ImageAttachment
    var onDelete: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var resizeTranslation: CGSize = .zero

    private var uiImage: UIImage? {
        attachment.imageData.flatMap { UIImage(data: $0) }
    }

    private var displayWidth: CGFloat {
        max(48, attachment.width + resizeTranslation.width)
    }

    private var displayHeight: CGFloat {
        max(48, attachment.height + resizeTranslation.height)
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
        }
        .frame(width: displayWidth, height: displayHeight)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) { deleteHandle }
        .overlay(alignment: .bottomTrailing) { resizeHandle }
        .position(
            x: attachment.positionX + displayWidth / 2 + dragTranslation.width,
            y: attachment.positionY + displayHeight / 2 + dragTranslation.height
        )
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    attachment.positionX += value.translation.width
                    attachment.positionY += value.translation.height
                }
        )
    }

    private var deleteHandle: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
                .font(.system(size: 20))
                .background(Circle().fill(.white))
        }
        .offset(x: 10, y: -10)
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.accentColor)
            .font(.system(size: 20))
            .background(Circle().fill(.white))
            .offset(x: 10, y: 10)
            .highPriorityGesture(
                DragGesture()
                    .updating($resizeTranslation) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        attachment.width = max(48, attachment.width + value.translation.width)
                        attachment.height = max(48, attachment.height + value.translation.height)
                    }
            )
    }
}

/// 드래그로 옮기고 모서리 손잡이로 크기를 조절할 수 있는, 키보드로
/// 입력하는 텍스트 상자.
struct TextBoxAttachmentView: View {
    @Bindable var attachment: TextBoxAttachment
    var onDelete: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var resizeTranslation: CGSize = .zero
    @FocusState private var isEditing: Bool

    private var displayWidth: CGFloat {
        max(80, attachment.width + resizeTranslation.width)
    }

    private var displayHeight: CGFloat {
        max(44, attachment.height + resizeTranslation.height)
    }

    var body: some View {
        TextEditor(text: $attachment.text)
            .font(.system(size: attachment.fontSize))
            .foregroundStyle(Color(hex: attachment.colorHex) ?? .primary)
            .scrollContentBackground(.hidden)
            .padding(6)
            .focused($isEditing)
            .frame(width: displayWidth, height: displayHeight)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor.opacity(isEditing ? 0.8 : 0.4), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) { deleteHandle }
            .overlay(alignment: .bottomTrailing) { resizeHandle }
            .position(
                x: attachment.positionX + displayWidth / 2 + dragTranslation.width,
                y: attachment.positionY + displayHeight / 2 + dragTranslation.height
            )
            .gesture(
                DragGesture(minimumDistance: isEditing ? .infinity : 4)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        attachment.positionX += value.translation.width
                        attachment.positionY += value.translation.height
                    }
            )
    }

    private var deleteHandle: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
                .font(.system(size: 20))
                .background(Circle().fill(.white))
        }
        .offset(x: 10, y: -10)
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.accentColor)
            .font(.system(size: 20))
            .background(Circle().fill(.white))
            .offset(x: 10, y: 10)
            .highPriorityGesture(
                DragGesture()
                    .updating($resizeTranslation) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        attachment.width = max(80, attachment.width + value.translation.width)
                        attachment.height = max(44, attachment.height + value.translation.height)
                    }
            )
    }
}

extension Color {
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
