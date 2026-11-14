import Foundation

struct HWPConverter {
    static var pythonURL: URL? {
        if let python = EngineLocations.readerPython { return python }
        guard !EngineLocations.isIsolated else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let tools = [
            home.appendingPathComponent(".local/bin/hwp5odt"),
            URL(fileURLWithPath: "/opt/homebrew/bin/hwp5odt"),
            URL(fileURLWithPath: "/usr/local/bin/hwp5odt")
        ]
        return tools.compactMap { tool -> URL? in
            guard FileManager.default.isExecutableFile(atPath: tool.path) else { return nil }
            // Keep the virtualenv Python path intact; resolving its symlink loses its packages.
            let python = tool.resolvingSymlinksInPath().deletingLastPathComponent()
                .appendingPathComponent("python")
            return FileManager.default.isExecutableFile(atPath: python.path) ? python : nil
        }.first
    }

    static var isAvailable: Bool { FileeDocumentConverter.isAvailable || (pythonURL != nil && LibreOfficeConverter.isAvailable) }
    static let setupMessage = "‘문서 변환 준비’에서 필요한 기능을 설치한 뒤 다시 변환해 주세요."
    static let qualityNotice = "HWP 5 문서를 변환합니다. 복잡한 표·수식·도형·쪽 배치는 원본과 달라질 수 있으니 결과를 확인해 주세요."

    func convert(input: URL, format: SupportedFormat, outputDirectory: URL) throws -> URL {
        guard [.docx, .pdf].contains(format) else { throw ConversionError.unsupportedConversion }
        if !LibreOfficeConverter.isAvailable || Self.pythonURL == nil {
            return try FileeDocumentConverter().convert(input: input, format: format, directory: outputDirectory).output
        }
        guard let python = Self.pythonURL, LibreOfficeConverter.isAvailable else {
            throw ConversionError.conversionFailed(Self.setupMessage)
        }
        let intermediate = outputDirectory.appendingPathComponent("hwp-intermediate.odt")
        do {
            _ = try ConversionProcess.run(
                executable: python, arguments: ["-c", Self.bridge, input.path, intermediate.path],
                directory: outputDirectory
            )
        } catch {
            throw ConversionError.conversionFailed(
                "HWP 문서를 읽지 못했습니다. HWP 5 형식인지, 암호·배포용 보호가 없는지 확인해 주세요. HWPX와 구형 HWP 3 문서는 지원하지 않습니다."
            )
        }
        return try LibreOfficeConverter().convert(
            input: intermediate, format: format, outputDirectory: outputDirectory
        )
    }

    // pyhwp's generated ODF can contain nonstandard style properties. LibreOffice
    // normalizes those on import. Skip only the intermediate ODF schema check;
    // HWP parsing, ZIP/XML integrity and nonempty body checks remain mandatory.
    private static let bridge = #"""
    import logging
    import sys
    from contextlib import closing
    from zipfile import ZipFile
    from lxml import etree
    from hwp5.xmlmodel import Hwp5File
    from hwp5.hwp5odt import ODTTransform, ODTPackage

    logging.disable(logging.CRITICAL)
    source, output = sys.argv[1:]
    with closing(Hwp5File(source)) as document:
        # Some valid third-party writers omit optional document summary metadata.
        # pyhwp assumes it exists even though the body does not depend on it.
        if '\x05HwpSummaryInformation' not in document:
            class EmptySummary:
                def events(self, **kwargs):
                    return iter(())
            document.summaryinfo = EmptySummary()
        if document.header.version[0] != 5:
            raise ValueError('Only HWP 5 is supported')
        if document.header.flags.password or document.header.flags.distributable:
            raise ValueError('Protected HWP documents are not supported')
        with closing(ODTPackage(output)) as package:
            ODTTransform(relaxng_compile=False).transform_hwp5_to_package(document, package)
    with ZipFile(output) as package:
        if package.testzip() is not None:
            raise ValueError('Invalid intermediate document')
        parser = etree.XMLParser(resolve_entities=False, no_network=True)
        root = etree.fromstring(package.read('content.xml'), parser)
        ns = {'office': 'urn:oasis:names:tc:opendocument:xmlns:office:1.0',
              'text': 'urn:oasis:names:tc:opendocument:xmlns:text:1.0',
              'draw': 'urn:oasis:names:tc:opendocument:xmlns:drawing:1.0'}
        body = root.find('office:body/office:text', ns)
        if body is None or not (''.join(body.itertext()).strip() or body.findall('.//draw:image', ns)):
            raise ValueError('HWP body is empty or unsupported')
    """#
}
