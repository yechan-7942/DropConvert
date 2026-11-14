import PDFKit
import XCTest
@testable import DropConvert

final class WordConversionTests: XCTestCase {
    func testAppBundleInstallationIsDetected() throws {
        let bundleExecutable = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        guard FileManager.default.isExecutableFile(atPath: bundleExecutable) else {
            throw XCTSkip("LibreOffice 앱 번들이 설치된 환경에서 검사합니다.")
        }
        XCTAssertTrue(LibreOfficeConverter.isAvailable)
        XCTAssertNotNil(LibreOfficeConverter.executableURL)
    }

    func testWordConvertsToReadablePDFWithoutChangingSource() throws {
        guard LibreOfficeConverter.isAvailable else {
            throw XCTSkip("LibreOffice가 설치된 환경에서 검사합니다.")
        }
        let fixture = try XCTUnwrap(Bundle.module.url(
            forResource: "word-sample", withExtension: "docx", subdirectory: "Fixtures"
        ))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("한글 문서.docx")
        try FileManager.default.copyItem(at: fixture, to: source)
        let original = try Data(contentsOf: source)
        let input = FileTypeDetector().inputFile(from: source)
        XCTAssertEqual(ConversionRegistry().outputFormats(for: input), [.pdf] + (HWPExportConverter.isAvailable ? [.hwp] : []))
        let result = try ConversionManager().convert(ConversionRequest(
            input: input, outputFormat: .pdf, outputDirectory: directory
        ))
        let document = try XCTUnwrap(PDFDocument(url: result.output))
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(document.string?.contains("Word to PDF conversion check") == true)
        XCTAssertTrue(document.string?.contains("한글 문장") == true)
        // 텍스트 추출만으로는 글꼴 누락으로 한글이 보이지 않는 문제를 잡지 못한다.
        let selection = try XCTUnwrap(document.findString("한글 문장", fromSelection: nil, withOptions: []))
        let page = try XCTUnwrap(selection.pages.first)
        let bounds = selection.bounds(for: page)
        let width = Int(ceil(bounds.width * 3))
        let height = Int(ceil(bounds.height * 3))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: 3, y: 3)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let visiblePixels = (0..<(width * height)).filter { index in
            let offset = index * 4
            return pixels[offset] < 180 && pixels[offset + 1] < 180 && pixels[offset + 2] < 180
        }.count
        XCTAssertGreaterThan(visiblePixels, 30, "PDF에서 한글이 실제로 그려져야 합니다.")
        if let assets = FileManager.default.enumerator(atPath: "/System/Library/AssetsV2"),
           assets.allObjects.compactMap({ $0 as? String }).contains(where: {
               $0.hasPrefix("com_apple_MobileAsset_Font") && $0.hasSuffix("/NanumGothic.ttc")
           }) {
            let pdfData = try Data(contentsOf: result.output)
            XCTAssertNotNil(pdfData.range(of: Data("NanumGothic".utf8)),
                            "다운로드된 나눔고딕을 다른 글꼴로 바꾸지 않고 포함해야 합니다.")
        }
        XCTAssertEqual(try Data(contentsOf: source), original)
    }

    @MainActor
    func testSelectingNewFileClearsPreviousResult() {
        let model = ConversionViewModel()
        model.lastResult = ConversionResult(
            input: URL(fileURLWithPath: "/tmp/old.png"),
            output: URL(fileURLWithPath: "/tmp/old.jpg")
        )
        model.add(urls: [URL(fileURLWithPath: "/tmp/new.docx")])
        XCTAssertNil(model.lastResult)
    }
}
