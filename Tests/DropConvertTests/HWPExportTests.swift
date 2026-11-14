import PDFKit
import XCTest
@testable import DropConvert

final class HWPExportTests: XCTestCase {
    func testWordOffersHWPOnlyWithTheWriterAndVerifierInstalled() {
        let input = InputFile(url: URL(fileURLWithPath: "/tmp/문서.DOCX"), detectedType: nil)
        let formats = ConversionRegistry().outputFormats(for: input)
        XCTAssertEqual(formats.contains(.hwp), HWPExportConverter.isAvailable)
        XCTAssertEqual(SupportedFormat.hwp.fileExtension, "hwp")
        XCTAssertFalse(ConversionRegistry().outputFormats(for:
            InputFile(url: URL(fileURLWithPath: "/tmp/picture.png"), detectedType: .png)
        ).contains(.hwp))
    }

    func testWordToBinaryHWPWithKoreanTablesAndNoOverwrite() throws {
        guard HWPExportConverter.isAvailable, LibreOfficeConverter.isAvailable else {
            throw XCTSkip("HWP 저장 엔진과 LibreOffice 설치 필요")
        }
        let fixture = try XCTUnwrap(Bundle.module.url(
            forResource: "word-to-hwp-sample", withExtension: "docx", subdirectory: "Fixtures"
        ))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("한글 표 문서.docx")
        try FileManager.default.copyItem(at: fixture, to: source)
        let original = try Data(contentsOf: source)
        let existing = directory.appendingPathComponent("한글 표 문서.hwp")
        let sentinel = Data("existing result".utf8)
        try sentinel.write(to: existing)
        let result = try ConversionManager().convert(ConversionRequest(
            input: FileTypeDetector().inputFile(from: source), outputFormat: .hwp, outputDirectory: directory
        ))
        XCTAssertEqual(result.output.lastPathComponent, "한글 표 문서 (2).hwp")
        XCTAssertEqual(try Data(contentsOf: result.output).prefix(8), Data([0xD0,0xCF,0x11,0xE0,0xA1,0xB1,0x1A,0xE1]))
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertEqual(try Data(contentsOf: existing), sentinel)

        // Read through the app's independent HWP importer and render the Korean text.
        let pdf = try ConversionManager().convert(ConversionRequest(
            input: FileTypeDetector().inputFile(from: result.output), outputFormat: .pdf, outputDirectory: directory
        )).output
        let document = try XCTUnwrap(PDFDocument(url: pdf))
        let text = try XCTUnwrap(document.string)
        XCTAssertTrue(text.contains("한글"))
        XCTAssertTrue(text.contains("병합"))
        XCTAssertGreaterThan(document.pageCount, 0)

        // A nonmatching Word source must be refused, never silently accepted.
        let other = try XCTUnwrap(Bundle.module.url(
            forResource: "word-sample", withExtension: "docx", subdirectory: "Fixtures"
        ))
        XCTAssertThrowsError(try HWPExportConverter().verifyText(
            source: other, output: result.output, directory: directory,
            python: try XCTUnwrap(HWPConverter.pythonURL)
        ))
    }

    func testDamagedWordDoesNotCreateHWP() throws {
        guard HWPExportConverter.isAvailable else { throw XCTSkip("HWP 저장 엔진 설치 필요") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("damaged.docx")
        try Data("not a Word package".utf8).write(to: source)
        XCTAssertThrowsError(try ConversionManager().convert(ConversionRequest(
            input: FileTypeDetector().inputFile(from: source), outputFormat: .hwp, outputDirectory: directory
        )))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("damaged.hwp").path))
    }
}
