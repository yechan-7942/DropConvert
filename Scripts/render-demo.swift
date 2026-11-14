import AppKit
import SwiftUI

// README용 사용 흐름 예시를 실제 SwiftUI 뷰로 재현한다. 변환 검증은 별도 테스트에서 수행한다.
@main
struct RenderDemo {
    @MainActor
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let source = directory.appendingPathComponent("한글 문서.docx")
        for state in 0..<3 {
            let model = ConversionViewModel()
            if state == 1 { model.add(urls: [source]) }
            if state == 2 {
                model.lastResult = ConversionResult(input: source, output: source.deletingPathExtension().appendingPathExtension("pdf"))
                model.statusMessage = "변환 완료: 한글 문서.pdf"
            }
            let view = NSHostingView(rootView: ContentView(viewModel: model)
                .frame(width: 480, height: 570)
                .background(Color(nsColor: .windowBackgroundColor)))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 570),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = view
            view.frame = NSRect(x: 0, y: 0, width: 480, height: 570)
            view.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                throw CocoaError(.fileWriteUnknown)
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try data.write(to: directory.appendingPathComponent("step-\(state + 1).png"))
        }
    }
}
