import SwiftUI

struct VideoDownloadView: View {
    @ObservedObject var viewModel: VideoDownloadViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("YouTube 저장")
                .font(.system(size: 24, weight: .semibold))
            Text("영상 링크를 넣으면 MP4로 저장합니다.")
                .foregroundStyle(.secondary)
            TextField("https://www.youtube.com/watch?v=…", text: $viewModel.link)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isDownloading)
                .onSubmit { startDownload() }
                .accessibilityLabel("YouTube 영상 주소")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("저장 위치").font(.caption).foregroundStyle(.secondary)
                    Text(viewModel.outputDirectory.path)
                        .font(.caption)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer()
                Button("변경…") { viewModel.chooseOutputDirectory() }
                    .disabled(viewModel.isDownloading)
            }
            if let message = viewModel.dependencyMessage {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            if viewModel.isDownloading {
                if let progress = viewModel.progress {
                    ProgressView(value: progress)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption).monospacedDigit()
                } else {
                    ProgressView().controlSize(.small)
                }
                Button("중단") { viewModel.cancel() }
            } else {
                Button("영상 저장") { startDownload() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canDownload)
            }
            Text(viewModel.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
            if viewModel.downloadedFile != nil {
                Button("Finder에서 열기") { viewModel.revealDownload() }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startDownload() {
        guard viewModel.canDownload else { return }
        Task { await viewModel.download() }
    }
}
