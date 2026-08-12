import PDFKit
import PencilKit
import UIKit

/// 원본 PDF 페이지와 애플펜슬로 그린 필기를 하나의 이미지로 합쳐
/// 공유/내보내기가 가능한 새 PDF 데이터를 만든다. 원본과 필기 데이터는
/// 그대로 보존되며, 이 함수는 오직 내보내기용 사본만 생성한다.
enum PDFAnnotationFlattener {
    static func flatten(pdfData: Data, annotations: [PDFPageAnnotation]) -> Data? {
        guard let document = PDFDocument(data: pdfData), document.pageCount > 0 else {
            return nil
        }

        let drawingsByPage: [Int: PKDrawing] = Dictionary(
            uniqueKeysWithValues: annotations.compactMap { annotation in
                guard let data = annotation.drawingData,
                      let drawing = try? PKDrawing(data: data) else {
                    return nil
                }
                return (annotation.pageIndex, drawing)
            }
        )

        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        return renderer.pdfData { context in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let pageBounds = page.bounds(for: .mediaBox)
                context.beginPage(withBounds: pageBounds, pageInfo: [:])
                let cgContext = context.cgContext

                cgContext.saveGState()
                cgContext.translateBy(x: 0, y: pageBounds.height)
                cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()

                if let drawing = drawingsByPage[index] {
                    let image = drawing.image(from: pageBounds, scale: UIScreen.main.scale)
                    image.draw(in: pageBounds)
                }
            }
        }
    }
}
