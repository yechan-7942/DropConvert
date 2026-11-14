import XCTest
@testable import DropConvert

final class VideoDownloadTests: XCTestCase {
    func testVideoLinksAndPlaylistHandling() {
        for link in [
            "https://www.youtube.com/watch?v=video123&list=list123",
            "https://youtu.be/video123?t=20",
            "https://youtube.com/shorts/video123",
            "https://m.youtube.com/watch?v=video123"
        ] {
            XCTAssertNotNil(VideoDownloadViewModel.videoURL(from: link), link)
        }
        for link in [
            "", "ytv \"url\"", "file:///tmp/video", "https://youtube.com.evil.example/watch?v=x",
            "https://youtube.com/playlist?list=x", "https://youtu.be/", "https://youtube.com/watch"
        ] {
            XCTAssertNil(VideoDownloadViewModel.videoURL(from: link), link)
        }
    }

    @MainActor
    func testDownloadsWithoutShellExpansionAndReportsFinalFile() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("한글 영상.mp4")
        let arguments = directory.appendingPathComponent("arguments.txt")
        let encodedPath = String(decoding: try JSONEncoder().encode(output.path), as: UTF8.self)
        let executable = try makeExecutable(in: directory, script: """
        printf '%s\\n' "$@" > \(quote(arguments.path))
        printf '__DC_PROGRESS__ 50.0%%\\n'
        sleep 0.3
        printf 'video' > \(quote(output.path))
        printf '%s\\n' \(quote("__DC_FILE__" + encodedPath))
        """)
        let model = VideoDownloadViewModel(executable: executable, ffmpeg: executable, outputDirectory: directory)
        model.link = "https://www.youtube.com/watch?v=sample&unused=$(touch%20UNEXPECTED)"
        await model.download()
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.downloadedFile, output)
        XCTAssertEqual(model.progress, 1)
        XCTAssertFalse(model.isDownloading)
        let passed = try String(contentsOf: arguments, encoding: .utf8).components(separatedBy: "\n")
        XCTAssertEqual(passed[passed.count - 2], model.link)
        XCTAssertTrue(passed.contains("--no-playlist"))
        XCTAssertTrue(passed.contains("--no-overwrites"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("UNEXPECTED").path))
    }

    @MainActor
    func testFailureDoesNotExposeACompletedDownload() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = try makeExecutable(in: directory, script: "echo 'ERROR: Video unavailable' >&2\nexit 1")
        let model = VideoDownloadViewModel(executable: executable, ffmpeg: executable, outputDirectory: directory)
        model.link = "https://youtu.be/example"
        await model.download()
        XCTAssertEqual(model.errorMessage, "ERROR: Video unavailable")
        XCTAssertNil(model.downloadedFile)
        XCTAssertFalse(model.isDownloading)
    }

    @MainActor
    func testMissingOutputIsNotReportedAsSuccess() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = try makeExecutable(in: directory, script: "exit 0")
        let model = VideoDownloadViewModel(executable: executable, ffmpeg: executable, outputDirectory: directory)
        model.link = "https://youtu.be/example"
        await model.download()
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.downloadedFile)
    }

    @MainActor
    func testDownloadCanBeCancelledWhileUIIsResponsive() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = try makeExecutable(in: directory, script: "trap 'exit 130' INT\nwhile :; do sleep 0.1; done")
        let model = VideoDownloadViewModel(executable: executable, ffmpeg: executable, outputDirectory: directory)
        model.link = "https://youtu.be/example"
        let download = Task { await model.download() }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(model.isDownloading)
        model.cancel()
        await download.value
        XCTAssertFalse(model.isDownloading)
        XCTAssertNil(model.downloadedFile)
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.statusMessage.contains("중단했습니다"))
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeExecutable(in directory: URL, script: String) throws -> URL {
        let executable = directory.appendingPathComponent("test-downloader")
        try ("#!/bin/sh\n" + script + "\n").write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        return executable
    }

    private func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
