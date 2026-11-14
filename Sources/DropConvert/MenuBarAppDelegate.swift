import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private let viewModel = ConversionViewModel()
    private let videoDownload = VideoDownloadViewModel()
    private var statusItem: NSStatusItem?
    private var conversionPanel: ConversionPanel?

    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        configureStatusItem()
        refreshLoginStatus()
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "didConfigureLaunchAtLogin") {
            setLaunchAtLogin(true)
            defaults.set(true, forKey: "didConfigureLaunchAtLogin")
        }
        if !FileeDocumentConverter.isAvailable && !LibreOfficeConverter.isAvailable {
            togglePanel()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if conversionPanel?.isVisible != true {
            togglePanel()
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        videoDownload.cancel()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "DropConvert")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "DropConvert — 파일 변환"
            button.target = self
            button.action = #selector(togglePanel)
        }
        statusItem = item
    }

    @objc private func togglePanel() {
        if let panel = conversionPanel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        refreshLoginStatus()
        let panel: ConversionPanel
        if let existing = conversionPanel {
            panel = existing
        } else {
            panel = ConversionPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 540),
                styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "DropConvert"
            panel.isReleasedWhenClosed = false
            panel.isFloatingPanel = true
            // Finder에서 파일을 선택하거나 드래그해도 패널을 유지한다.
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: MenuBarContentView(
                appDelegate: self,
                viewModel: viewModel,
                videoDownload: videoDownload
            ))
            conversionPanel = panel
        }
        if let button = statusItem?.button, let window = button.window {
            let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
            let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            if let screen {
                let x = min(max(anchor.maxX - panel.frame.width, screen.minX),
                            max(screen.minX, screen.maxX - panel.frame.width))
                let y = max(screen.minY, anchor.minY - panel.frame.height - 6)
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        } else {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func refreshLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            loginError = "시스템 설정의 로그인 항목에서 DropConvert를 허용해 주세요."
        } else if launchAtLogin {
            loginError = nil
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginError = "자동 실행 설정을 변경하지 못했습니다: \(error.localizedDescription)"
        }
        refreshLoginStatus()
    }

    func openLoginSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

private final class ConversionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        orderOut(sender)
    }
}
