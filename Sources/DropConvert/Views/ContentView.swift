import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ConversionViewModel
    var configureEngines: () -> Void = {}
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Text("DropConvert")
                .font(.system(size: 24, weight: .semibold))
            Text("파일을 빠르고 안전하게 변환하세요")
                .foregroundStyle(.secondary)

            dropArea
            if !viewModel.files.isEmpty {
                fileSummary
                if viewModel.files.first?.isHWP == true {
                    Text(HWPConverter.qualityNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if viewModel.files.first?.isWord == true {
                    Text(HWPExportConverter.isAvailable
                         ? "HWP 저장 시 원문 글자 보존을 검사합니다. 글꼴·표·쪽 배치는 원본과 달라질 수 있습니다."
                         : HWPExportConverter.setupMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !viewModel.availableFormats.isEmpty {
                    formatPicker
                }
                if (viewModel.files.first?.isWord == true || viewModel.files.first?.isHWP == true),
                   !HWPExportConverter.isAvailable {
                    Button("필요한 문서 변환 기능 설치") { configureEngines() }
                        .disabled(viewModel.isConverting)
                }
            }
            if !viewModel.files.isEmpty || viewModel.lastResult != nil {
                actionArea
            }
            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard !viewModel.isConverting else { return false }
            _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in viewModel.add(urls: [url]) }
            }
            return true
        }
    }

    private var dropArea: some View {
        VStack(spacing: 12) {
            Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
            Text("파일을 이곳으로 드래그하세요")
                .font(.title3)
            Button("파일 선택") { viewModel.chooseFiles() }
                .disabled(viewModel.isConverting)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6])))
    }

    private var fileSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(viewModel.files) { file in
                Label("\(file.fileName) · \(file.sourceFormat)", systemImage: "doc")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formatPicker: some View {
        HStack {
            Text("어떤 형식으로 변환할까요?")
            Spacer()
            Picker("출력 형식", selection: $viewModel.selectedFormat) {
                ForEach(viewModel.availableFormats) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .labelsHidden()
            .disabled(viewModel.isConverting)
            .frame(width: 150)
        }
    }

    private var actionArea: some View {
        VStack(spacing: 12) {
            if viewModel.isConverting {
                ProgressView("변환 중…")
            } else if !viewModel.files.isEmpty {
                Button("변환하기") { viewModel.convert() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                    .disabled(viewModel.files.isEmpty || !viewModel.availableFormats.contains(viewModel.selectedFormat))
            }
            if viewModel.lastResult != nil {
                Button("Finder에서 열기") { viewModel.openResultInFinder() }
            }
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
