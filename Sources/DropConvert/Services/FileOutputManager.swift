import Foundation

struct FileOutputManager {
    func outputURL(for input: URL, format: SupportedFormat, directory: URL) throws -> URL {
        let baseName = input.deletingPathExtension().lastPathComponent
        let initial = directory.appendingPathComponent("\(baseName).\(format.fileExtension)")
        if !FileManager.default.fileExists(atPath: initial.path) {
            return initial
        }
        var index = 2
        while true {
            let candidate = directory.appendingPathComponent("\(baseName) (\(index)).\(format.fileExtension)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
