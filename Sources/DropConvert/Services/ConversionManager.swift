import Foundation
import UniformTypeIdentifiers

struct ConversionManager {
    private let outputManager = FileOutputManager()
    private let imageConverter = ImageConverter()
    private let pdfConverter = PDFConverter()

    func convert(_ request: ConversionRequest) throws -> ConversionResult {
        guard ConversionRegistry().outputFormats(for: request.input).contains(request.outputFormat) else {
            throw ConversionError.unsupportedConversion
        }
        let output = try outputManager.outputURL(
            for: request.input.url,
            format: request.outputFormat,
            directory: request.outputDirectory
        )
        let inputType = request.input.detectedType
        var notice: String?
        if request.input.isHWP || request.input.isWord {
            let temporaryDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(
                at: temporaryDirectory, withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
            let generated: URL
            if request.input.isHWP {
                generated = try HWPConverter().convert(
                    input: request.input.url, format: request.outputFormat,
                    outputDirectory: temporaryDirectory
                )
            } else if request.outputFormat == .hwp {
                generated = try HWPExportConverter().convert(
                    input: request.input.url, outputDirectory: temporaryDirectory
                )
            } else if !LibreOfficeConverter.isAvailable {
                let converted = try FileeDocumentConverter().convert(
                    input: request.input.url, format: .pdf, directory: temporaryDirectory
                )
                generated = converted.output
                notice = converted.notice
            } else {
                generated = try LibreOfficeConverter().convertToPDF(
                    input: request.input.url, outputDirectory: temporaryDirectory
                )
            }
            try FileManager.default.moveItem(at: generated, to: output)
        } else if request.outputFormat == .pdf,
                  let inputType,
                  !inputType.conforms(to: .pdf) {
            try pdfConverter.convertImagesToPDF(inputs: [request.input.url], output: output)
        } else if let inputType, inputType.conforms(to: .pdf) {
            try pdfConverter.convertPDF(input: request.input.url, output: output, format: request.outputFormat)
        } else if inputType?.conforms(to: .image) == true {
            try imageConverter.convert(input: request.input.url, output: output, format: request.outputFormat)
        } else {
            throw ConversionError.unsupportedConversion
        }
        return ConversionResult(input: request.input.url, output: output, notice: notice)
    }
}
