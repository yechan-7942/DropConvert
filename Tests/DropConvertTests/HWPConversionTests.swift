import PDFKit
import UniformTypeIdentifiers
import XCTest
@testable import DropConvert

final class HWPConversionTests: XCTestCase {
    func testHWPDoesNotRequireRegisteredUTType() {
        let input = InputFile(url: URL(fileURLWithPath: "/tmp/한글 문서.HWP"), detectedType: nil)
        XCTAssertTrue(input.isHWP)
        XCTAssertEqual(ConversionRegistry().outputFormats(for: input), HWPConverter.isAvailable ? [.pdf, .docx] : [])
        let data = InputFile(url: URL(fileURLWithPath: "/tmp/unknown.bin"), detectedType: .data)
        XCTAssertTrue(ConversionRegistry().outputFormats(for: data).isEmpty)
    }

    func testInvalidHWPDoesNotLeaveOutputOrChangeSource() throws {
        guard HWPConverter.isAvailable else { throw XCTSkip("HWP 엔진 설치 필요") }
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("손상된 문서.hwp")
        let data = Data("not a HWP document".utf8)
        try data.write(to: source)
        for format in [SupportedFormat.pdf, .docx] {
            XCTAssertThrowsError(try ConversionManager().convert(ConversionRequest(
                input: FileTypeDetector().inputFile(from: source), outputFormat: format, outputDirectory: directory
            )))
        }
        XCTAssertEqual(try Data(contentsOf: source), data)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [source.lastPathComponent])
    }

    // A supplied real document stays outside the repository. Run with
    // DROPCONVERT_HWP_SAMPLE=/absolute/path/sample.hwp swift test --filter HWPConversionTests
    func testRealHWPConvertsToWordAndReadablePDF() throws {
        guard HWPConverter.isAvailable else { throw XCTSkip("HWP 엔진 설치 필요") }
        guard let path = ProcessInfo.processInfo.environment["DROPCONVERT_HWP_SAMPLE"] else {
            throw XCTSkip("실제 HWP 문서 경로가 지정되지 않았습니다.")
        }
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("한글 공백 문서.HWP")
        try FileManager.default.copyItem(atPath: path, toPath: source.path)
        let original = try Data(contentsOf: source)
        let input = FileTypeDetector().inputFile(from: source)
        let existing = directory.appendingPathComponent("한글 공백 문서.pdf")
        try Data("existing file".utf8).write(to: existing)
        let pdf = try ConversionManager().convert(ConversionRequest(
            input: input, outputFormat: .pdf, outputDirectory: directory
        )).output
        XCTAssertEqual(pdf.lastPathComponent, "한글 공백 문서 (2).pdf")
        let document = try XCTUnwrap(PDFDocument(url: pdf))
        XCTAssertGreaterThan(document.pageCount, 0)
        let text = try XCTUnwrap(document.string)
        let korean = try XCTUnwrap(text.first { $0 >= "가" && $0 <= "힣" })
        let selection = try XCTUnwrap(document.findString(String(korean), fromSelection: nil, withOptions: []))
        let page = try XCTUnwrap(selection.pages.first)
        let bounds = selection.bounds(for: page)
        let width = max(1, Int(ceil(bounds.width * 3)))
        let height = max(1, Int(ceil(bounds.height * 3)))
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
        XCTAssertGreaterThan((0..<(width * height)).filter { pixels[$0 * 4] < 180 }.count, 10)

        let word = try ConversionManager().convert(ConversionRequest(
            input: input, outputFormat: .docx, outputDirectory: directory
        )).output
        let xml = try ConversionProcess.run(
            executable: URL(fileURLWithPath: "/usr/bin/unzip"),
            arguments: ["-p", word.path, "word/document.xml"], directory: directory
        )
        XCTAssertTrue(xml.contains("w:document"))
        // Roundtrip the Word output, checking text is editable and survived both exports.
        let roundtripDirectory = directory.appendingPathComponent("roundtrip")
        try FileManager.default.createDirectory(at: roundtripDirectory, withIntermediateDirectories: true)
        let roundtrip = try LibreOfficeConverter().convertToPDF(input: word, outputDirectory: roundtripDirectory)
        let wordText = try XCTUnwrap(PDFDocument(url: roundtrip)?.string)
        XCTAssertTrue(wordText.contains(String(korean)))
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "existing file")
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
