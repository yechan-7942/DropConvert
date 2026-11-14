import Foundation

struct DocumentFontEnvironment {
    static func environment(executable: URL, configurationDirectory: URL) throws -> [String: String] {
        let manager = FileManager.default
        // macOS의 headless 변환에서 시스템 글꼴을 놓치는 버전에 대비한다.
        // LibreOffice 번들과 원본 문서는 수정하지 않고, 자식 프로세스에만 적용한다.
        var fontDirectories = [
            URL(fileURLWithPath: "/System/Library/Fonts", isDirectory: true),
            URL(fileURLWithPath: "/Library/Fonts", isDirectory: true),
            manager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Fonts", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Microsoft Word.app/Contents/Resources/DFonts", isDirectory: true),
            executable.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/fonts", isDirectory: true)
        ]
        // 나눔고딕 등 macOS가 별도로 내려받은 글꼴도 포함한다.
        // Font7/Font8처럼 OS 버전마다 바뀌는 폴더 이름을 고정하지 않는다.
        for root in ["/System/Library/AssetsV2", "/System/Library/Assets"] {
            if let assets = try? manager.contentsOfDirectory(
                at: URL(fileURLWithPath: root, isDirectory: true),
                includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            ) {
                fontDirectories += assets.filter { $0.lastPathComponent.hasPrefix("com_apple_MobileAsset_Font") }
            }
        }
        fontDirectories = fontDirectories.filter { manager.fileExists(atPath: $0.path) }
        let cache = try manager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("DropConvert/Fontconfig", isDirectory: true)
        try manager.createDirectory(at: cache, withIntermediateDirectories: true)
        let directories = fontDirectories.map { "<dir>\(xmlEscaped($0.path))</dir>" }.joined(separator: "\n")
        let configuration = """
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
        \(directories)
        <cachedir>\(xmlEscaped(cache.path))</cachedir>
        </fontconfig>
        """
        let file = configurationDirectory.appendingPathComponent("fonts.conf")
        try configuration.write(to: file, atomically: true, encoding: .utf8)
        var environment = EngineLocations.cleanEnvironment
        environment["FONTCONFIG_FILE"] = file.path
        environment["FONTCONFIG_PATH"] = configurationDirectory.path
        return environment
    }

    private static func xmlEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
