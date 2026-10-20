import XCTest
@testable import DropConvert

final class FileOutputManagerTests: XCTestCase {
    func testOutputURLAddsSuffixWhenNameExists() throws {
        let directory = FileManager.default.temporaryDirectory
        let input = directory.appendingPathComponent("sample.png")
        let existing = directory.appendingPathComponent("sample.jpg")
        FileManager.default.createFile(atPath: existing.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: existing) }

        let output = try FileOutputManager().outputURL(for: input, format: .jpeg, directory: directory)
        XCTAssertEqual(output.lastPathComponent, "sample (2).jpg")
    }
}
