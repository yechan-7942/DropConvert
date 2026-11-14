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

    var availableFormats: [SupportedFormat] {
        Array(Set(files.flatMap { registry.outputFormats(for: $0) }))
            .sorted { $0.displayName < $1.displayName }
    }

    func add(urls: [URL]) {
        guard !isConverting else { return }
        let newFiles = Array(urls.filter { $0.isFileURL }.prefix(1).map(detector.inputFile(from:)))
        files = newFiles
        lastResult = nil
        if let format = availableFormats.first {
            selectedFormat = format
            statusMessage = "\(files.count)개 파일을 감지했습니다. 출력 형식을 선택하세요."
        } else {
            if files.first?.isHWP == true, !HWPConverter.isAvailable {
                statusMessage = HWPConverter.setupMessage
            } else if files.first?.isWord == true {
                statusMessage = "‘문서 변환 준비’에서 필요한 기능을 설치한 뒤 변환해 주세요."
            } else {
                statusMessage = "지원 가능한 출력 형식이 없습니다."
            }
        }
        errorMessage = nil
    }

    func chooseFiles() {
        guard !isConverting else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    func refreshAfterEngineSetup() {
        guard !isConverting, !files.isEmpty else { return }
        add(urls: files.map(\.url))
    }

    func convert() {
        guard !isConverting, let file = files.first, availableFormats.contains(selectedFormat) else { return }
        isConverting = true
        errorMessage = nil
        lastResult = nil
        statusMessage = "변환 중…"
        let request = ConversionRequest(
            input: file, outputFormat: selectedFormat,
            outputDirectory: file.url.deletingLastPathComponent()
        )
        Task {
            defer { isConverting = false }
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try ConversionManager().convert(request)
                }.value
                lastResult = result
                statusMessage = "변환 완료: \(result.output.lastPathComponent)"
                    + (request.outputFormat == .hwp ? "\n원문 글자 보존 검사 통과. 글꼴·표·쪽 배치는 결과를 확인해 주세요."
                       : (file.isHWP ? "\n원본과 표·수식·쪽 배치를 비교해 주세요." : ""))
                if let notice = result.notice { statusMessage += "\n" + notice }
                files.removeAll()
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "변환하지 못했습니다."
            }
        }
    }

    func openResultInFinder() {
        guard let output = lastResult?.output else { return }
        NSWorkspace.shared.activateFileViewerSelecting([output])
    }
}
