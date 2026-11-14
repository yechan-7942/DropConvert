import Darwin
import Foundation

/// File-backed output avoids pipe deadlocks when a parser emits many warnings.
struct ConversionProcess {
    static func run(
        executable: URL, arguments: [String], directory: URL,
        environment: [String: String]? = nil, timeout: TimeInterval = 120,
        outputFile: URL? = nil
    ) throws -> String {
        let log = directory.appendingPathComponent("process-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        let outputHandle: FileHandle?
        if let outputFile {
            FileManager.default.createFile(atPath: outputFile.path, contents: nil)
            outputHandle = try FileHandle(forWritingTo: outputFile)
        } else {
            outputHandle = nil
        }
        defer {
            try? handle.close()
            try? outputHandle?.close()
            try? FileManager.default.removeItem(at: log)
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = directory
        process.standardOutput = outputHandle ?? handle
        process.standardError = handle
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            // Only terminate the child created by this conversion.
            let grace = Date().addingTimeInterval(2)
            while process.isRunning, Date() < grace { Thread.sleep(forTimeInterval: 0.05) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            throw ConversionError.conversionFailed("변환 시간이 초과되었습니다. 문서가 손상되었거나 지원하지 않는 개체를 포함하는지 확인해 주세요.")
        }
        process.waitUntilExit()
        let data = (try? Data(contentsOf: log)) ?? Data()
        let message = String(decoding: data.suffix(4000), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw ConversionError.conversionFailed(message.isEmpty ? "변환 엔진 실행에 실패했습니다." : message)
        }
        return message
    }
}
