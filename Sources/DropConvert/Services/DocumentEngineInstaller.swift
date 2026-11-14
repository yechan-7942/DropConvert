import CryptoKit
import Darwin
import Foundation

struct DocumentEngineInstaller: Sendable {
    let root: URL
    let useExistingTools: Bool
    typealias Progress = @Sendable (String, Double?) -> Void

    init(root: URL = EngineLocations.root, useExistingTools: Bool = !EngineLocations.isIsolated) {
        self.root = root
        self.useExistingTools = useExistingTools
    }

    struct Archive: Sendable {
        let name: String
        let url: URL
        let sha256: String
    }
    static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x64"
        #endif
    }
    static var fileeArchive: Archive {
        let name = "Filee-2.4.0-osx-\(architecture).tar.gz"
        return Archive(name: name,
            url: URL(string: "https://github.com/KnifeLemon/Filee/releases/download/v2.4.0/\(name)")!,
            sha256: architecture == "arm64"
                ? "a257eb796712a24ee58e3b33a1265d44d00e74121f3e276d4d6a2c880155577e"
                : "df66108323715baa11ff88df001af7beea83eb5206b0064de02d1aceace72ed1")
    }
    static var uvArchive: Archive {
        let name = "uv-\(architecture == "arm64" ? "aarch64" : "x86_64")-apple-darwin.tar.gz"
        return Archive(name: name,
            url: URL(string: "https://github.com/astral-sh/uv/releases/download/0.12.12/\(name)")!,
            sha256: architecture == "arm64"
                ? "46740540b63fdee9a6cb2e19baf3f1f475b850c440a33e63455087a6871263f1"
                : "0dc8cd6c961582b0d140b5398f96b23502885277fb3464241456a2435e460dfa")
    }

    func install(progress: @escaping Progress) async throws {
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let lock = open(root.appendingPathComponent(".install.lock").path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard lock >= 0 else { throw failure("설치 폴더에 접근할 수 없습니다.") }
        defer { close(lock) }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else {
            throw failure("다른 DropConvert에서 설치 중입니다. 잠시 후 다시 시도해 주세요.")
        }
        defer { flock(lock, LOCK_UN) }
        let work = root.appendingPathComponent("setup-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: work) }

        let filee = root.appendingPathComponent("Filee/Filee.app/Contents/MacOS/filee-cli")
        if !manager.isExecutableFile(atPath: filee.path) {
            progress("문서 변환 도구 준비 중…", nil)
            let archive = try await download(Self.fileeArchive, progress: progress)
            let unpacked = work.appendingPathComponent("filee", isDirectory: true)
            try await unpack(archive, into: unpacked)
            let package = unpacked.appendingPathComponent("Filee-2.4.0-osx-\(Self.architecture)")
            let cli = package.appendingPathComponent("Filee.app/Contents/MacOS/filee-cli")
            let writer = cli.deletingLastPathComponent().appendingPathComponent("engines/rhwp/rhwp")
            guard [cli, writer].allSatisfy({ manager.isExecutableFile(atPath: $0.path) }) else {
                throw failure("다운로드한 문서 변환 도구가 올바르지 않습니다.")
            }
            _ = try await run(cli, ["version"], work: work)
            let destination = root.appendingPathComponent("Filee")
            guard !manager.fileExists(atPath: destination.path) else {
                throw failure("기존 문서 도구 폴더를 덮어쓸 수 없습니다. 설치 폴더를 확인해 주세요.")
            }
            try manager.moveItem(at: package, to: destination)
        }
        progress("문서 변환 도구 확인 중…", nil)
        _ = try await run(filee, ["version"], work: work)
        let writer = filee.deletingLastPathComponent().appendingPathComponent("engines/rhwp/rhwp")
        guard manager.isExecutableFile(atPath: writer.path) else {
            throw failure("한글 저장 도구가 없습니다. 설치 폴더를 확인해 주세요.")
        }

        if useExistingTools, let python = HWPConverter.pythonURL,
           (try? await run(python, ["-c", Self.readerCheck], work: work)) != nil {
            progress("문서 변환 준비 완료", 1)
            return
        }
        let reader = root.appendingPathComponent("Reader", isDirectory: true)
        let python = reader.appendingPathComponent("bin/python")
        if manager.fileExists(atPath: reader.appendingPathComponent(".ready").path),
           (try? await run(python, ["-c", Self.readerCheck], work: work)) != nil {
            progress("문서 변환 준비 완료", 1)
            return
        }
        // A previous failed install must not keep advertising a ready verifier.
        try? manager.removeItem(at: reader.appendingPathComponent(".ready"))
        progress("글자 보존 검사 도구 준비 중…", nil)
        let runtime = root.appendingPathComponent("Runtime", isDirectory: true)
        try manager.createDirectory(at: runtime, withIntermediateDirectories: true)
        let uvName = Self.uvArchive.name.replacingOccurrences(of: ".tar.gz", with: "")
        let uv = runtime.appendingPathComponent("\(uvName)/uv")
        if !manager.isExecutableFile(atPath: uv.path) {
            progress("설치 도구 준비 중…", nil)
            let archive = try await download(Self.uvArchive, progress: progress)
            let unpacked = work.appendingPathComponent("uv", isDirectory: true)
            try await unpack(archive, into: unpacked)
            let downloaded = unpacked.appendingPathComponent(uvName)
            guard manager.isExecutableFile(atPath: downloaded.appendingPathComponent("uv").path) else {
                throw failure("다운로드한 설치 도구가 올바르지 않습니다.")
            }
            try manager.moveItem(at: downloaded, to: runtime.appendingPathComponent(uvName))
        }
        progress("글자 보존 검사 환경 설치 중…", nil)
        var environment = EngineLocations.cleanEnvironment
        environment["UV_PYTHON_INSTALL_DIR"] = runtime.appendingPathComponent("Python").path
        environment["UV_PYTHON_BIN_DIR"] = runtime.appendingPathComponent("bin").path
        environment["UV_CACHE_DIR"] = root.appendingPathComponent("Cache").path
        _ = try await run(uv, ["--no-config", "venv", "--python", "3.12.14", "--managed-python",
                              "--allow-existing", "--no-project", reader.path], work: work, environment: environment)
        _ = try await run(uv, ["--no-config", "pip", "install", "--python", python.path,
                              "--index-url", "https://pypi.org/simple", "pyhwp==0.1b15",
                              "lxml==6.1.3", "six==1.17.0"], work: work, environment: environment)
        progress("설치 결과 확인 중…", nil)
        _ = try await run(python, ["-c", Self.readerCheck], work: work, environment: environment)
        try Data("pyhwp 0.1b15\n".utf8).write(to: reader.appendingPathComponent(".ready"), options: .atomic)
        progress("문서 변환 준비 완료", 1)
    }

    static let readerCheck = "from hwp5.xmlmodel import Hwp5File; from lxml import etree; import six; print('ready')"

    static func verify(_ archive: URL, sha256 expected: String) throws {
        let handle = try FileHandle(forReadingFrom: archive)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { hash.update(data: data) }
        let actual = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == expected.lowercased() else {
            throw ConversionError.conversionFailed("다운로드 파일 검증에 실패했습니다. 다시 시도해 주세요.")
        }
    }

    private func download(_ archive: Archive, progress: @escaping Progress) async throws -> URL {
        let cache = root.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let saved = cache.appendingPathComponent(archive.name)
        if (try? Self.verify(saved, sha256: archive.sha256)) != nil { return saved }
        let delegate = DownloadProgress { fraction in progress("\(archive.name.hasPrefix("Filee") ? "문서 변환 도구" : "설치 도구") 다운로드 중…", fraction) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 1800
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (file, response) = try await session.download(from: archive.url)
        defer { try? FileManager.default.removeItem(at: file) }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw failure("다운로드 서버에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요.")
        }
        try Self.verify(file, sha256: archive.sha256)
        if FileManager.default.fileExists(atPath: saved.path) { try FileManager.default.removeItem(at: saved) }
        try FileManager.default.moveItem(at: file, to: saved)
        return saved
    }

    private func unpack(_ archive: URL, into directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Only archives matching pinned official SHA256 values reach tar.
        _ = try await run(URL(fileURLWithPath: "/usr/bin/tar"), ["-xzf", archive.path, "-C", directory.path], work: directory)
    }

    private func run(_ executable: URL, _ arguments: [String], work: URL,
                     environment: [String: String]? = nil) async throws -> String {
        try Task.checkCancellation()
        return try await Task.detached {
            try ConversionProcess.run(executable: executable, arguments: arguments, directory: work,
                                      environment: environment ?? EngineLocations.cleanEnvironment, timeout: 900)
        }.value
    }
    private func failure(_ message: String) -> ConversionError { .conversionFailed(message) }
}

private final class DownloadProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let update: @Sendable (Double?) -> Void
    init(update: @escaping @Sendable (Double?) -> Void) { self.update = update }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        update(totalBytesExpectedToWrite > 0 ? min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) : nil)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
