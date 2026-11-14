import Foundation
import UniformTypeIdentifiers

enum SupportedFormat: String, CaseIterable, Identifiable, Sendable {
    case pdf, png, jpeg, docx, hwp

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .pdf: "PDF"
        case .png: "PNG"
        case .jpeg: "JPG"
        case .docx: "Word (.docx)"
        case .hwp: "한글 (.hwp)"
        }
    }
    var fileExtension: String { rawValue == "jpeg" ? "jpg" : rawValue }
    var contentType: UTType {
        switch self {
        case .pdf: .pdf
        case .png: .png
        case .jpeg: .jpeg
        case .docx: UTType(filenameExtension: "docx") ?? .data
        case .hwp: UTType(filenameExtension: "hwp") ?? .data
        }
    }
}

struct InputFile: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let detectedType: UTType?

    var fileName: String { url.lastPathComponent }
    var isHWP: Bool { url.pathExtension.lowercased() == "hwp" }
    var isWord: Bool {
        url.pathExtension.lowercased() == "docx" ||
        detectedType?.identifier == "org.openxmlformats.wordprocessingml.document"
    }
    var sourceFormat: String {
        isHWP ? "한글 문서 (HWP)" : (detectedType?.localizedDescription ?? url.pathExtension.uppercased())
    }
}

struct ConversionRequest: Sendable {
    let input: InputFile
    let outputFormat: SupportedFormat
    let outputDirectory: URL
}

struct ConversionResult: Identifiable, Sendable {
    let id = UUID()
    let input: URL
    let output: URL
    var notice: String? = nil
}

enum ConversionError: LocalizedError {
    case unsupportedInput
    case unsupportedConversion
    case outputExists(URL)
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedInput: "지원하지 않는 입력 파일 형식입니다."
        case .unsupportedConversion: "현재 설치된 변환 엔진으로 지원하지 않는 변환입니다."
        case .outputExists(let url): "출력 파일이 이미 존재합니다: \(url.lastPathComponent)"
        case .conversionFailed(let reason): reason
        }
    }
}
