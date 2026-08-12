import SwiftUI

/// 필기 노트 캔버스 뒤에 깔리는 종이 배경. `Canvas`로 직접 그려서
/// OneNote 스타일의 백지/줄친 종이/점선지/모눈종이와, 손글씨 악보용
/// 오선지를 표현한다.
struct NotePaperBackgroundView: View {
    let style: NoteBackgroundStyle

    private let paperColor = Color(red: 0.973, green: 0.965, blue: 0.933)
    private let ruleLineColor = Color(red: 0.72, green: 0.74, blue: 0.7)
    private let marginLineColor = Color(red: 0.82, green: 0.36, blue: 0.36)
    private let staffLineColor = Color(red: 0.35, green: 0.35, blue: 0.4)

    var body: some View {
        switch style {
        case .blank:
            paperColor

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

        case .dotGrid:
            Canvas { context, size in
                let spacing: CGFloat = 32
                let dotRadius: CGFloat = 1.6
                var y: CGFloat = spacing
                while y < size.height {
                    var x: CGFloat = spacing
                    while x < size.width {
                        let rect = CGRect(
                            x: x - dotRadius, y: y - dotRadius,
                            width: dotRadius * 2, height: dotRadius * 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(ruleLineColor))
                        x += spacing
                    }
                    y += spacing
                }
            }
            .background(paperColor)

        case .squareGrid:
            Canvas { context, size in
                let spacing: CGFloat = 32

                var x: CGFloat = spacing
                while x < size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(ruleLineColor), lineWidth: 0.75)
                    x += spacing
                }

                var y: CGFloat = spacing
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(ruleLineColor), lineWidth: 0.75)
                    y += spacing
                }
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
