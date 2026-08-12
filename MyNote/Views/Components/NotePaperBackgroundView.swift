import SwiftUI

/// 필기 노트 캔버스 뒤에 깔리는 종이 배경. `Canvas`로 직접 그려서
/// 줄노트(가로줄 + 왼쪽 여백선)와 오선지(5줄 보표 반복)를 표현한다.
struct NotePaperBackgroundView: View {
    let style: NoteBackgroundStyle

    private let paperColor = Color(red: 0.973, green: 0.965, blue: 0.933)
    private let ruleLineColor = Color(red: 0.72, green: 0.74, blue: 0.7)
    private let marginLineColor = Color(red: 0.82, green: 0.36, blue: 0.36)
    private let staffLineColor = Color(red: 0.35, green: 0.35, blue: 0.4)

    var body: some View {
        switch style {
        case .blank:
            Color(uiColor: .systemBackground)
        case .lined:
            Canvas { context, size in
                let lineSpacing: CGFloat = 40
                var y: CGFloat = lineSpacing
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(ruleLineColor), lineWidth: 1)
                    y += lineSpacing
                }

                let marginX: CGFloat = 70
                var marginPath = Path()
                marginPath.move(to: CGPoint(x: marginX, y: 0))
                marginPath.addLine(to: CGPoint(x: marginX, y: size.height))
                context.stroke(marginPath, with: .color(marginLineColor), lineWidth: 1.5)
            }
            .background(paperColor)
        case .staffPaper:
            Canvas { context, size in
                let staffLineSpacing: CGFloat = 10
                let staffGroupSpacing: CGFloat = 70
                let sideMargin: CGFloat = 30
                var staffTop: CGFloat = 50
                while staffTop < size.height {
                    for lineIndex in 0..<5 {
                        let y = staffTop + CGFloat(lineIndex) * staffLineSpacing
                        var path = Path()
                        path.move(to: CGPoint(x: sideMargin, y: y))
                        path.addLine(to: CGPoint(x: size.width - sideMargin, y: y))
                        context.stroke(path, with: .color(staffLineColor), lineWidth: 1)
                    }
                    staffTop += staffGroupSpacing
                }
            }
            .background(paperColor)
        }
    }
}
