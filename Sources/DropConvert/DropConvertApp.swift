import SwiftUI

@main
struct DropConvertApp: App {
    @StateObject private var viewModel = ConversionViewModel()

    var body: some Scene {
        WindowGroup {
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
    }
}
