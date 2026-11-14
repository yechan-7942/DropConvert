import Foundation

enum EngineLocations {
    // Allows an integration-test process to use a clean directory without touching installed tools.
    static var isIsolated: Bool { ProcessInfo.processInfo.environment["DROPCONVERT_ENGINE_ROOT"] != nil }
    static var root: URL {
        if let path = ProcessInfo.processInfo.environment["DROPCONVERT_ENGINE_ROOT"] {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DropConvert/Engines", isDirectory: true)
    }
    static var reader: URL { root.appendingPathComponent("Reader", isDirectory: true) }
    static var readerPython: URL? {
        let python = reader.appendingPathComponent("bin/python")
        return FileManager.default.isExecutableFile(atPath: python.path)
            && FileManager.default.fileExists(atPath: reader.appendingPathComponent(".ready").path) ? python : nil
    }
    static var filee: URL { root.appendingPathComponent("Filee", isDirectory: true) }
    static var fileeExecutable: URL? {
        let executable = filee.appendingPathComponent("Filee.app/Contents/MacOS/filee-cli")
        let writer = executable.deletingLastPathComponent().appendingPathComponent("engines/rhwp/rhwp")
        return [executable, writer].allSatisfy { FileManager.default.isExecutableFile(atPath: $0.path) }
            ? executable : nil
    }
    static var cleanEnvironment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        for key in ["PYTHONHOME", "PYTHONPATH", "VIRTUAL_ENV", "CONDA_PREFIX",
                    "UV_INDEX", "UV_DEFAULT_INDEX", "UV_INDEX_URL", "UV_EXTRA_INDEX_URL",
                    "PIP_INDEX_URL", "PIP_EXTRA_INDEX_URL"] { environment.removeValue(forKey: key) }
        return environment
    }
}
