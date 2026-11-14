import Foundation

struct FileeDocumentConverter {
    static var isAvailable: Bool { EngineLocations.fileeExecutable != nil }

    func convert(input: URL, format: SupportedFormat, directory: URL) throws -> (output: URL, notice: String?) {
        guard [.pdf, .docx, .hwp].contains(format), let executable = EngineLocations.fileeExecutable else {
            throw ConversionError.unsupportedConversion
        }
        let exports = directory.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        let reportURL = directory.appendingPathComponent("result.json")
        var environment = try DocumentFontEnvironment.environment(executable: executable, configurationDirectory: directory)
        environment["FILEE_DATA_DIR"] = directory.appendingPathComponent("engine-profile").path
        _ = try ConversionProcess.run(
            executable: executable,
            arguments: ["convert", input.path, "--to", format.fileExtension, "-o", exports.path, "--json"],
            directory: directory, environment: environment, outputFile: reportURL
        )
        let report = try JSONDecoder().decode(Report.self, from: Data(contentsOf: reportURL))
        guard report.converted == 1, report.failed == 0, report.files.count == 1,
              let file = report.files.first, file.state == "done", file.outputs.count == 1,
              let path = file.outputs.first else {
            throw ConversionError.conversionFailed("문서 변환 엔진이 정상 결과를 반환하지 않았습니다.")
        }
        let result = URL(fileURLWithPath: path).standardizedFileURL
        guard result.pathExtension.lowercased() == format.fileExtension,
              result.resolvingSymlinksInPath().deletingLastPathComponent() == exports.resolvingSymlinksInPath(),
              let size = try? result.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else {
            throw ConversionError.conversionFailed("변환 결과 파일을 확인할 수 없습니다.")
        }
        let notice = (file.missingFonts ?? []).isEmpty ? nil
            : "원본 글꼴 일부가 없어 대체 글꼴을 사용했습니다. 글꼴과 줄바꿈을 확인해 주세요."
        return (result, notice)
    }

    private struct Report: Decodable {
        let converted: Int
        let failed: Int
        let files: [File]
        struct File: Decodable {
            let state: String
            let outputs: [String]
            let missingFonts: [String]?
        }
    }
}
