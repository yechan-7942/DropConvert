import Darwin
import PDFKit
import XCTest
@testable import DropConvert

final class DocumentEngineInstallerTests: XCTestCase {
    func testChecksumRejectsChangedDownload() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("archive")
        try Data("abc".utf8).write(to: file)
        let checksum = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        XCTAssertNoThrow(try DocumentEngineInstaller.verify(file, sha256: checksum))
        try Data("changed".utf8).write(to: file)
        XCTAssertThrowsError(try DocumentEngineInstaller.verify(file, sha256: checksum))
    }

    func testConcurrentInstallIsRefusedBeforeDownloading() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let descriptor = open(directory.appendingPathComponent(".install.lock").path, O_CREAT | O_RDWR, 0o600)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        defer { close(descriptor) }
        XCTAssertEqual(flock(descriptor, LOCK_EX | LOCK_NB), 0)
        defer { flock(descriptor, LOCK_UN) }
        do {
            try await DocumentEngineInstaller(root: directory, useExistingTools: false).install { _, _ in }
            XCTFail("A concurrent installer must not run")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("설치 중"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Downloads").path))
    }

    func testWordPDFWorksDirectlyWithTheInstalledEngine() throws {
        guard FileeDocumentConverter.isAvailable else { throw XCTSkip("문서 변환 도구 설치 필요") }
        let fixture = try XCTUnwrap(Bundle.module.url(
            forResource: "word-sample", withExtension: "docx", subdirectory: "Fixtures"
        ))
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try Data(contentsOf: fixture)
        let result = try FileeDocumentConverter().convert(input: fixture, format: .pdf, directory: directory)
        let pdf = try XCTUnwrap(PDFDocument(url: result.output))
        XCTAssertEqual(pdf.pageCount, 1)
        XCTAssertTrue(pdf.string?.contains("한글") == true)
        XCTAssertEqual(try Data(contentsOf: fixture), original)
    }

    func testComplexWordPDFActuallyRendersKorean() throws {
        guard FileeDocumentConverter.isAvailable else { throw XCTSkip("문서 변환 도구 설치 필요") }
        let fixture = try XCTUnwrap(Bundle.module.url(
            forResource: "word-to-hwp-sample", withExtension: "docx", subdirectory: "Fixtures"
        ))
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try FileeDocumentConverter().convert(input: fixture, format: .pdf, directory: directory)
        let pdf = try XCTUnwrap(PDFDocument(url: result.output))
        // The lower-level engine can find LibreOffice even when our app uses Filee.
        // Its Korean font configuration must be inherited too; text extraction alone misses this regression.
        let selection = try XCTUnwrap(pdf.findString("한글", fromSelection: nil, withOptions: []))
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
        let visible = (0..<(width * height)).filter { pixels[$0 * 4] < 180 }.count
        XCTAssertGreaterThan(visible, 30, "한글이 추출될 뿐 아니라 실제로 보여야 합니다.")
    }

    @MainActor
    func testRefreshingSetupKeepsTheSelectedFile() {
        let model = ConversionViewModel()
        let source = URL(fileURLWithPath: "/tmp/선택한 문서.docx")
        model.add(urls: [source])
        model.refreshAfterEngineSetup()
        XCTAssertEqual(model.files.first?.url, source)
        if FileeDocumentConverter.isAvailable { XCTAssertTrue(model.availableFormats.contains(.pdf)) }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
