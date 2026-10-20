import Foundation
import UniformTypeIdentifiers

struct FileTypeDetector {
    func detect(url: URL) -> UTType? {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type
        }
        return UTType(filenameExtension: url.pathExtension)
    }

    func inputFile(from url: URL) -> InputFile {
        InputFile(url: url, detectedType: detect(url: url))
    }
}
