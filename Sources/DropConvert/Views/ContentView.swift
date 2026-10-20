import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ConversionViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 24) {
            Text("DropConvert")
                .font(.system(size: 30, weight: .semibold))
            Text("파일을 빠르고 안전하게 변환하세요")
                .foregroundStyle(.secondary)

            dropArea
            if !viewModel.files.isEmpty {
                fileSummary
                formatPicker
                actionArea
            }
            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            providers.first?.loadObject(ofClass: URL.self) { url, _ in
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
                .foregroundStyle(isTargeted ? .accent : .secondary)
            Text("파일을 이곳으로 드래그하세요")
                .font(.title3)
            Button("파일 선택") { viewModel.chooseFiles() }
        }
        .frame(maxWidth: .infinity, minHeight: 190)
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
            .frame(width: 150)
        }
    }

    private var actionArea: some View {
        VStack(spacing: 12) {
            if viewModel.isConverting {
                ProgressView("변환 중…")
            } else {
                Button("변환하기") { viewModel.convert() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
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
