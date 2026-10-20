import Foundation
import UniformTypeIdentifiers

struct ConversionManager {
    private let outputManager = FileOutputManager()
    private let imageConverter = ImageConverter()
    private let pdfConverter = PDFConverter()

    func convert(_ request: ConversionRequest) throws -> ConversionResult {
        let output = try outputManager.outputURL(
            for: request.input.url,
            format: request.outputFormat,
            directory: request.outputDirectory
        )
        let inputType = request.input.detectedType
        if inputType?.identifier == "org.openxmlformats.wordprocessingml.document" &&
                    request.outputFormat == .pdf {
            let temporaryDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(
                at: temporaryDirectory, withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
            let generated = try LibreOfficeConverter().convertToPDF(
                input: request.input.url, outputDirectory: temporaryDirectory
            )
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
        return ConversionResult(input: request.input.url, output: output)
    }
}
