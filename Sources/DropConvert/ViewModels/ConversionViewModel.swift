import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ConversionViewModel: ObservableObject {
    @Published var files: [InputFile] = []
    @Published var selectedFormat: SupportedFormat = .png
    @Published var isConverting = false
    @Published var statusMessage = "파일을 여기에 놓거나 파일을 추가하세요."
    @Published var errorMessage: String?
    @Published var lastResult: ConversionResult?

    private let detector = FileTypeDetector()
    private let registry = ConversionRegistry()
    private let manager = ConversionManager()

    var availableFormats: [SupportedFormat] {
        Array(Set(files.flatMap { registry.outputFormats(for: $0) }))
            .sorted { $0.displayName < $1.displayName }
    }

    func add(urls: [URL]) {
        let newFiles = Array(urls.filter { $0.isFileURL }.prefix(1).map(detector.inputFile(from:)))
        files = newFiles
        if let format = availableFormats.first {
            selectedFormat = format
            statusMessage = "\(files.count)개 파일을 감지했습니다. 출력 형식을 선택하세요."
        } else {
            statusMessage = "지원 가능한 출력 형식이 없습니다."
        }
        errorMessage = nil
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    func convert() {
        guard let file = files.first, availableFormats.contains(selectedFormat) else { return }
        isConverting = true
        errorMessage = nil
        defer { isConverting = false }
        do {
            let result = try manager.convert(ConversionRequest(
                input: file,
                outputFormat: selectedFormat,
                outputDirectory: file.url.deletingLastPathComponent()
            ))
            lastResult = result
            statusMessage = "변환 완료: \(result.output.lastPathComponent)"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "변환하지 못했습니다."
        }
    }

    func openResultInFinder() {
        guard let output = lastResult?.output else { return }
        NSWorkspace.shared.activateFileViewerSelecting([output])
    }
}
