import SwiftUI
import PDFKit

/// 한 번에 한 페이지씩 보여주는 읽기 전용 PDF 뷰. 실제 상호작용(넘기기)은
/// 위에 겹쳐진 PDFCanvasOverlay 와 페이지 내비게이션 바가 처리한다.
struct PDFPageRepresentable: UIViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.isUserInteractionEnabled = false
        pdfView.backgroundColor = .secondarySystemBackground
        if let page = document.page(at: pageIndex) {
            pdfView.go(to: page)
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
        if let page = document.page(at: pageIndex) {
            uiView.go(to: page)
        }
    }
}
