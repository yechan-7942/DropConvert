import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appDelegate: MenuBarAppDelegate
    @ObservedObject var viewModel: ConversionViewModel
    @ObservedObject var videoDownload: VideoDownloadViewModel
    @State private var selectedTab = 0
    @State private var showingSetup = false
    @StateObject private var engineSetup = EngineSetupViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Picker("작업", selection: $selectedTab) {
                Text("파일 변환").tag(0)
                Text("YouTube 저장").tag(1)
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], 16)
            ScrollView {
                if selectedTab == 0 {
                    ContentView(viewModel: viewModel, configureEngines: { showingSetup = true })
                } else {
                    VideoDownloadView(viewModel: videoDownload)
                }
            }
            Divider()
            Button("문서 변환 준비") { showingSetup = true }
                .padding(.top, 10)
                .disabled(viewModel.isConverting)
            HStack {
                Toggle("로그인 시 자동 실행", isOn: Binding(
                    get: { appDelegate.launchAtLogin },
                    set: { appDelegate.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.checkbox)
                Spacer()
                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(16)
            if let message = appDelegate.loginError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.horizontal, .bottom], 16)
                Button("로그인 항목 설정 열기") {
                    appDelegate.openLoginSettings()
                }
                .padding(.bottom, 12)
            }

        }
        .frame(width: 480, height: 540)
        .onAppear { appDelegate.refreshLoginStatus() }
        .onChange(of: engineSetup.isInstalling) { installing in
            if !installing { viewModel.refreshAfterEngineSetup() }
        }
        .sheet(isPresented: $showingSetup, onDismiss: { viewModel.refreshAfterEngineSetup() }) {
            EngineSetupView(model: engineSetup)
        }
    }
}
