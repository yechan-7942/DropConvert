import Foundation
import SwiftUI

@MainActor
final class EngineSetupViewModel: ObservableObject {
    @Published private(set) var isInstalling = false
    @Published private(set) var documentsReady = false
    @Published private(set) var hwpWritingReady = false
    @Published private(set) var status = "필요한 기능만 한 번 설치하면 됩니다."
    @Published private(set) var progress: Double?
    @Published private(set) var error: String?
    var isReady: Bool { documentsReady && hwpWritingReady }

    init() { refresh() }

    func refresh() {
        documentsReady = FileeDocumentConverter.isAvailable
        hwpWritingReady = HWPExportConverter.isAvailable
        if isReady { status = "문서 변환 준비가 완료되었습니다." }
    }

    func install() {
        guard !isInstalling else { return }
        isInstalling = true
        error = nil
        progress = nil
        status = "설치를 준비하고 있습니다…"
        Task { [self] in
            defer { isInstalling = false; refresh() }
            do {
                try await DocumentEngineInstaller().install { [weak self] message, fraction in
                    Task { @MainActor in
                        self?.status = message
                        self?.progress = fraction
                    }
                }
                status = "준비 완료. 파일을 선택해 바로 변환할 수 있습니다."
            } catch {
                self.error = error.localizedDescription
                status = "설치를 완료하지 못했습니다. 연결을 확인한 뒤 다시 시도해 주세요."
            }
        }
    }
}
