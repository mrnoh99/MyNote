import SwiftUI
import PencilKit

enum PencilToolKind: String, CaseIterable {
    case lasso
    case pen
    case highlighter
    case eraser

    var systemImage: String {
        switch self {
        case .lasso: return "lasso"
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        }
    }
}

enum PencilWidthCategory: String, CaseIterable {
    case thin
    case medium
    case thick

    /// 도구 종류별로 굵기 값(포인트)이 다르게 느껴지도록 보정한다.
    /// (형광펜은 같은 "얇음"이어도 펜보다 두껍게 그려야 자연스럽다.)
    func width(for kind: PencilToolKind) -> CGFloat {
        switch kind {
        case .highlighter:
            switch self {
            case .thin: return 14
            case .medium: return 22
            case .thick: return 32
            }
        default:
            switch self {
            case .thin: return 2
            case .medium: return 5
            case .thick: return 10
            }
        }
    }

    var indicatorHeight: CGFloat {
        switch self {
        case .thin: return 3
        case .medium: return 5
        case .thick: return 8
        }
    }
}

/// 필기 도구(펜 종류/굵기/색상) 선택 상태. 캔버스는 이 값이 바뀔 때마다
/// `pkTool`을 다시 읽어 `PKCanvasView.tool`에 반영한다.
final class PencilToolState: ObservableObject {
    @Published var kind: PencilToolKind = .pen
    @Published var color: Color = .black
    @Published var width: PencilWidthCategory = .medium

    var pkTool: PKTool {
        switch kind {
        case .pen:
            return PKInkingTool(.pen, color: UIColor(color), width: width.width(for: .pen))
        case .highlighter:
            return PKInkingTool(
                .marker,
                color: UIColor(color).withAlphaComponent(0.5),
                width: width.width(for: .highlighter)
            )
        case .eraser:
            return PKEraserTool(.bitmap)
        case .lasso:
            return PKLassoTool()
        }
    }
}

/// GoodNotes류 앱처럼 캔버스 위쪽에 고정으로 떠 있는 커스텀 필기 도구
/// 모음. iOS 기본 PKToolPicker 대신 이 툴바로 펜/형광펜/지우개/올가미,
/// 굵기, 색상, 실행 취소·다시 실행을 직접 제어한다.
struct PencilToolbarView: View {
    @ObservedObject var toolState: PencilToolState
    var canUndo: Bool
    var canRedo: Bool
    var onUndo: () -> Void
    var onRedo: () -> Void

    private let presetColors: [Color] = [.black, .red, .blue, .green, .orange]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    ForEach(PencilToolKind.allCases, id: \.self) { kind in
                        toolButton(kind)
                    }
                }

                Divider().frame(height: 24)

                HStack(spacing: 10) {
                    ForEach(PencilWidthCategory.allCases, id: \.self) { width in
                        widthButton(width)
                    }
                }

                Divider().frame(height: 24)

                HStack(spacing: 10) {
                    ForEach(presetColors, id: \.self) { color in
                        colorSwatch(color)
                    }
                    ColorPicker("사용자 지정 색상", selection: $toolState.color)
                        .labelsHidden()
                        .frame(width: 26, height: 26)
                }

                Divider().frame(height: 24)

                HStack(spacing: 6) {
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!canUndo)

                    Button(action: onRedo) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!canRedo)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private func toolButton(_ kind: PencilToolKind) -> some View {
        let isSelected = toolState.kind == kind
        return Button {
            toolState.kind = kind
        } label: {
            Image(systemName: kind.systemImage)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 34, height: 34)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .background(
                    Circle().fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                )
        }
    }

    private func widthButton(_ width: PencilWidthCategory) -> some View {
        let isSelected = toolState.width == width
        return Button {
            toolState.width = width
        } label: {
            Capsule()
                .fill(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 26, height: width.indicatorHeight)
                .frame(width: 34, height: 34)
        }
    }

    private func colorSwatch(_ color: Color) -> some View {
        let isSelected = toolState.color == color
        return Button {
            toolState.color = color
        } label: {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle().stroke(Color.primary, lineWidth: isSelected ? 2 : 0)
                )
                .padding(2)
        }
    }
}
