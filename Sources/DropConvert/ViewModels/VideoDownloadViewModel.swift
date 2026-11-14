import AppKit
import Foundation
import SwiftUI

@MainActor
final class VideoDownloadViewModel: ObservableObject {
    @Published var link = ""
    @Published private(set) var isDownloading = false
    @Published private(set) var progress: Double?
    @Published private(set) var statusMessage = "YouTube 링크를 붙여 넣어 주세요."
    @Published private(set) var errorMessage: String?
    @Published private(set) var downloadedFile: URL?
    @Published private(set) var outputDirectory: URL

    private var process: Process?
    private var wasCancelled = false
    private let executable: URL?
    private let ffmpeg: URL?

    init(executable: URL? = VideoDownloadViewModel.findTool("yt-dlp"),
         ffmpeg: URL? = VideoDownloadViewModel.findTool("ffmpeg"),
         outputDirectory: URL? = nil) {
        self.executable = executable
        self.ffmpeg = ffmpeg
        self.outputDirectory = outputDirectory
            ?? UserDefaults.standard.url(forKey: "videoOutputDirectory")
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    nonisolated static func findTool(_ name: String) -> URL? {
        ["/opt/homebrew/bin", "/usr/local/bin"]
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    nonisolated static func videoURL(from text: String) -> URL? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: input),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["https", "http"].contains(parts.scheme?.lowercased() ?? ""),
              parts.user == nil, parts.password == nil,
              let host = parts.host?.lowercased() else { return nil }
        if host == "youtu.be" {
            return url.pathComponents.count == 2 ? url : nil
        }
        guard ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"].contains(host) else {
            return nil
        }
        if url.path == "/watch", parts.queryItems?.contains(where: { $0.name == "v" && !($0.value ?? "").isEmpty }) == true {
            return url
        }
        let path = url.pathComponents
        if path.count == 3, ["shorts", "live", "embed"].contains(path[1]) {
            return url
        }
        return nil
    }

    var canDownload: Bool {
        !isDownloading && Self.videoURL(from: link) != nil && executable != nil && ffmpeg != nil
    }

    var dependencyMessage: String? {
        if executable == nil { return "영상 저장에 yt-dlp가 필요합니다. 터미널에서 brew install yt-dlp로 설치해 주세요." }
        if ffmpeg == nil { return "영상과 음성을 합치려면 ffmpeg가 필요합니다. 터미널에서 brew install ffmpeg로 설치해 주세요." }
        return nil
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputDirectory
        panel.prompt = "저장 폴더 선택"
        NSApplication.shared.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
            UserDefaults.standard.set(url, forKey: "videoOutputDirectory")
        }
    }

    func revealDownload() {
        guard let downloadedFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([downloadedFile])
    }

    func cancel() {
        guard let process, process.isRunning else { return }
        wasCancelled = true
        statusMessage = "다운로드를 중단하는 중…"
        process.interrupt()
        Task { [weak self, weak process] in
            try? await Task.sleep(for: .seconds(3))
            if let process, self?.process === process, self?.wasCancelled == true, process.isRunning {
                process.terminate()
            }
        }
    }

    func download() async {
        guard !isDownloading else { return }
        downloadedFile = nil
        errorMessage = nil
        guard let url = Self.videoURL(from: link) else {
            errorMessage = "YouTube 영상 주소를 입력해 주세요. 재생목록 주소만으로는 저장할 수 없습니다."
            return
        }
        guard let executable, let ffmpeg else {
            errorMessage = dependencyMessage
            return
        }
        isDownloading = true
        wasCancelled = false
        progress = nil
        statusMessage = "영상 정보를 확인하는 중…"
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DropConvert-download-\(UUID().uuidString)", isDirectory: true)
        var reader: FileHandle?
        var writer: FileHandle?
        defer {
            try? reader?.close()
            try? writer?.close()
            try? FileManager.default.removeItem(at: temporaryDirectory)
            process = nil
            isDownloading = false
        }
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            let log = temporaryDirectory.appendingPathComponent("download.log")
            FileManager.default.createFile(atPath: log.path, contents: nil)
            writer = try FileHandle(forWritingTo: log)
            reader = try FileHandle(forReadingFrom: log)
            let job = Process()
            job.executableURL = executable
            job.arguments = [
                "--ignore-config", "--no-playlist", "--no-overwrites", "--newline", "--no-color",
                "--socket-timeout", "15", "--retries", "3", "--fragment-retries", "3",
                "--no-simulate", "--progress", "--progress-delta", "0.3",
                "-P", outputDirectory.path,
                "-o", "%(title).180B [%(id)s].%(ext)s",
                "-S", "vcodec:h264,res,acodec:m4a",
                "--merge-output-format", "mp4", "--remux-video", "mp4",
                "--ffmpeg-location", ffmpeg.path,
                "--progress-template", "download:__DC_PROGRESS__%(progress._percent_str)s",
                "--print", "after_move:__DC_FILE__%(filepath)j",
                "--", url.absoluteString
            ]
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
            job.environment = environment
            job.standardOutput = writer
            job.standardError = writer
            job.standardInput = FileHandle.nullDevice
            process = job
            try job.run()
            var pending = Data()
            var recentLines: [String] = []
            var resultURL: URL?
            func readUpdates() throws {
                pending.append(try reader?.readToEnd() ?? Data())
                while let newline = pending.firstIndex(of: 10) {
                    let line = String(decoding: pending[..<newline], as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    pending.removeSubrange(...newline)
                    if line.hasPrefix("__DC_PROGRESS__") {
                        let number = line.dropFirst("__DC_PROGRESS__".count)
                            .replacingOccurrences(of: "%", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        if let percent = Double(number), percent.isFinite {
                            progress = min(max(percent / 100, 0), 1)
                            statusMessage = percent >= 100 ? "다음 스트림 또는 MP4 파일을 준비하는 중…" : "영상·음성을 다운로드하는 중…"
                        }
                    } else if line.hasPrefix("__DC_FILE__") {
                        let json = Data(line.dropFirst("__DC_FILE__".count).utf8)
                        if let path = try? JSONDecoder().decode(String.self, from: json) {
                            resultURL = URL(fileURLWithPath: path)
                        }
                    } else if !line.isEmpty {
                        recentLines.append(line)
                        recentLines = Array(recentLines.suffix(8))
                    }
                }
            }
            while job.isRunning {
                try readUpdates()
                // 파일 로그를 읽으므로 파이프 버퍼로 작업이 멈추지 않고 UI도 유지된다.
                try await Task.sleep(for: .milliseconds(150))
            }
            try writer?.close()
            writer = nil
            try readUpdates()
            if wasCancelled {
                progress = nil
                statusMessage = "다운로드를 중단했습니다. 다시 저장하면 이어받습니다."
                return
            }
            guard job.terminationStatus == 0 else {
                let message = recentLines.filter { $0.contains("ERROR:") }.last
                    ?? recentLines.last ?? "영상 저장에 실패했습니다."
                throw DownloadError.failed(message)
            }
            guard let resultURL, FileManager.default.fileExists(atPath: resultURL.path) else {
                throw DownloadError.failed("저장된 파일을 확인하지 못했습니다. 저장 폴더를 확인해 주세요.")
            }
            downloadedFile = resultURL
            progress = 1
            statusMessage = "저장 완료: \(resultURL.lastPathComponent)"
        } catch {
            if let process, process.isRunning { process.interrupt() }
            progress = nil
            errorMessage = error.localizedDescription
            statusMessage = "저장하지 못했습니다."
        }
    }
}

private enum DownloadError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        switch self { case .failed(let message): message }
    }
}
