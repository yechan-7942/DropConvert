import Foundation
import AppKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

struct PDFConverter {
    func convertPDF(input: URL, output: URL, format: SupportedFormat) throws {
        guard let document = PDFDocument(url: input),
              let page = document.page(at: 0),
              let pageImage = render(page: page) else {
            throw ConversionError.conversionFailed("PDF를 읽거나 페이지를 렌더링할 수 없습니다.")
        }
        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL, format.contentType.identifier as CFString, 1, nil
        ) else {
            throw ConversionError.conversionFailed("이미지 출력 파일을 만들 수 없습니다.")
        }
        CGImageDestinationAddImage(destination, pageImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.conversionFailed("PDF 이미지 변환에 실패했습니다.")
        }
    }

    func convertImagesToPDF(inputs: [URL], output: URL) throws {
        let document = PDFDocument()
        for (index, input) in inputs.enumerated() {
            guard let image = NSImage(contentsOf: input),
                  let page = PDFPage(image: image) else {
                throw ConversionError.conversionFailed("이미지를 PDF 페이지로 변환할 수 없습니다.")
            }
            document.insert(page, at: index)
        }
        guard document.write(to: output) else {
            throw ConversionError.conversionFailed("PDF 파일 저장에 실패했습니다.")
        }
    }

    private func render(page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        guard let context = CGContext(
            data: nil,
            width: Int(bounds.width * scale),
            height: Int(bounds.height * scale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: bounds.width * scale, height: bounds.height * scale))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        return context.makeImage()
    }
}
