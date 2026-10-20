import Foundation
import UniformTypeIdentifiers

enum SupportedFormat: String, CaseIterable, Identifiable {
    case pdf, png, jpeg

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .pdf: "PDF"
        case .png: "PNG"
        case .jpeg: "JPG"
        }
    }
    var fileExtension: String { rawValue == "jpeg" ? "jpg" : rawValue }
    var contentType: UTType {
        switch self {
        case .pdf: .pdf
        case .png: .png
        case .jpeg: .jpeg
        }
    }
}

struct InputFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let detectedType: UTType?

    var fileName: String { url.lastPathComponent }
    var sourceFormat: String {
        detectedType?.localizedDescription ?? url.pathExtension.uppercased()
    }
}

struct ConversionRequest {
    let input: InputFile
    let outputFormat: SupportedFormat
    let outputDirectory: URL
}

struct ConversionResult: Identifiable {
    let id = UUID()
    let input: URL
    let output: URL
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
