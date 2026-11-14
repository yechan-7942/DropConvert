import AppKit
import SwiftUI

struct EngineSetupView: View {
    @ObservedObject var model: EngineSetupViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("문서 변환 준비")
                .font(.title2.bold())
            Text("처음 한 번만 설치하면 터미널 없이 Word와 한글 문서를 변환할 수 있습니다.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            row("이미지·PDF 이미지 변환", ready: true)
            row("Word → PDF · HWP → Word/PDF", ready: model.documentsReady)
            row("Word → HWP · 원문 글자 보존 검사", ready: model.hwpWritingReady)
            Text("최초 설치에는 인터넷과 추가 저장 공간이 필요합니다. 공식 도구를 내려받으며, 문서를 외부에 업로드하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.isInstalling {
                if let progress = model.progress {
                    ProgressView(value: progress)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            Text(model.status).font(.callout).fixedSize(horizontal: false, vertical: true)
            if let error = model.error {
                ScrollView { Text(error).font(.caption).textSelection(.enabled) }
                    .frame(maxHeight: 80)
            }
            HStack {
                if !model.isReady {
                    Button(model.error == nil ? "필요한 기능 설치" : "다시 시도") { model.install() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isInstalling)
                }
                Spacer()
                Button(model.isReady ? "완료" : "닫기") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            Text("이미지 변환은 추가 설치 없이 이용할 수 있습니다. 설치 중 창을 닫아도 설치는 계속됩니다.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { model.refresh() }
    }

    private func row(_ title: String, ready: Bool) -> some View {
        HStack {
            Image(systemName: ready ? "checkmark.circle" : "arrow.down.circle")
            Text(title).font(.callout)
            Spacer()
            Text(ready ? "사용 가능" : "설치 필요").font(.caption).foregroundStyle(.secondary)
        }
    }
}
