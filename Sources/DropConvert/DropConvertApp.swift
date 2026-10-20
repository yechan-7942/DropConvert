import SwiftUI
import AppKit

@main
struct DropConvertApp: App {
    @StateObject private var viewModel = ConversionViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 720, minHeight: 520)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("파일 추가") {
                    viewModel.chooseFiles()
                }
                .keyboardShortcut("o")
            }
        }

        MenuBarExtra("DropConvert", systemImage: "arrow.down.circle") {
            Button("DropConvert 열기") {
                openMainWindow()
            }

            Button("파일 선택…") {
                openMainWindow()
                viewModel.chooseFiles()
            }

            Divider()

            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
    }
}
