import Foundation

struct LibreOfficeConverter {
    static var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: "/usr/local/bin/libreoffice") ||
        FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/libreoffice")
    }

    func convertToPDF(input: URL, outputDirectory: URL) throws -> URL {
        guard let executable = ["/opt/homebrew/bin/libreoffice", "/usr/local/bin/libreoffice"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ConversionError.unsupportedConversion
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["--headless", "--convert-to", "pdf", "--outdir", outputDirectory.path, input.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "LibreOffice 변환 실패"
            throw ConversionError.conversionFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return outputDirectory.appendingPathComponent(input.deletingPathExtension().lastPathComponent + ".pdf")
    }
}
