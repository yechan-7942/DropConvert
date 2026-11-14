import Foundation

struct LibreOfficeConverter {
    static var executableURL: URL? {
        guard !EngineLocations.isIsolated else { return nil }
        return [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/LibreOffice.app/Contents/MacOS/soffice").path,
            "/opt/homebrew/bin/libreoffice",
            "/usr/local/bin/libreoffice"
        ]
        .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
        .map { URL(fileURLWithPath: $0) }
    }

    static var isAvailable: Bool {
        executableURL != nil
    }

    func convertToPDF(input: URL, outputDirectory: URL) throws -> URL {
        try convert(input: input, format: .pdf, outputDirectory: outputDirectory)
    }

    func convert(input: URL, format: SupportedFormat, outputDirectory: URL) throws -> URL {
        let filter: String
        switch format {
        case .pdf: filter = "pdf:writer_pdf_Export"
        case .docx: filter = "docx:Office Open XML Text"
        default: throw ConversionError.unsupportedConversion
        }
        guard let executable = Self.executableURL else {
            throw ConversionError.conversionFailed("문서 변환에는 LibreOffice 설치가 필요합니다.")
        }
        let profile = FileManager.default.temporaryDirectory
            .appendingPathComponent("DropConvert-LibreOffice-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: profile) }
        _ = try ConversionProcess.run(
            executable: executable,
            arguments: ["-env:UserInstallation=\(profile.absoluteString)",
                        "--headless", "--convert-to", filter,
                        "--outdir", outputDirectory.path, input.path],
            directory: profile,
            environment: try DocumentFontEnvironment.environment(executable: executable, configurationDirectory: profile)
        )
        let output = outputDirectory.appendingPathComponent(input.deletingPathExtension().lastPathComponent + ".\(format.fileExtension)")
        guard let size = try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else {
            throw ConversionError.conversionFailed("결과 파일이 생성되지 않았습니다. 문서가 손상되었거나 암호로 보호되어 있는지 확인해 주세요.")
        }
        return output
    }

}
