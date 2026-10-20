import UniformTypeIdentifiers

struct ConversionRegistry {
    func outputFormats(for input: InputFile) -> [SupportedFormat] {
        guard let type = input.detectedType else { return [] }
        if type.conforms(to: .pdf) {
            return [.png, .jpeg]
        }
        if type.conforms(to: .png) || type.conforms(to: .jpeg) ||
            type.conforms(to: .heic) || type.conforms(to: .tiff) ||
            type.conforms(to: .bmp) {
            return [.pdf, .png, .jpeg].filter { $0.contentType != type }
        }
        if type.conforms(to: UTType(filenameExtension: "docx") ?? .data) {
            return LibreOfficeConverter.isAvailable ? [.pdf] : []
        }
        return []
    }
}
