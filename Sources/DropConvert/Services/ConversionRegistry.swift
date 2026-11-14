import UniformTypeIdentifiers

struct ConversionRegistry {
    func outputFormats(for input: InputFile) -> [SupportedFormat] {
        // HWP often has only a dynamic/data UTType on Macs without Hancom installed.
        if input.isHWP { return HWPConverter.isAvailable ? [.pdf, .docx] : [] }
        if input.isWord {
            var formats: [SupportedFormat] = (LibreOfficeConverter.isAvailable || FileeDocumentConverter.isAvailable) ? [.pdf] : []
            if HWPExportConverter.isAvailable { formats.append(.hwp) }
            return formats
        }
        guard let type = input.detectedType else { return [] }
        if type.conforms(to: .pdf) {
            return [.png, .jpeg]
        }
        if type.conforms(to: .png) || type.conforms(to: .jpeg) ||
            type.conforms(to: .heic) || type.conforms(to: .tiff) ||
            type.conforms(to: .bmp) {
            return [.pdf, .png, .jpeg].filter { $0.contentType != type }
        }
        return []
    }
}
