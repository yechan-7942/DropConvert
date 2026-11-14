import Foundation

/// Filee's DOCX reader → HWPX writer → rhwp's binary HWP writer, all local.
/// A separate parser must confirm the original text before the result is published.
struct HWPExportConverter {
    static var engineDirectory: URL { EngineLocations.filee }
    static var executableURL: URL? { EngineLocations.fileeExecutable }
    static var isAvailable: Bool { executableURL != nil && HWPConverter.pythonURL != nil }
    static let setupMessage = "‘문서 변환 준비’에서 필요한 기능을 설치하면 한글 파일로 저장할 수 있습니다."

    func convert(input: URL, outputDirectory: URL) throws -> URL {
        guard Self.executableURL != nil, let python = HWPConverter.pythonURL else {
            throw ConversionError.conversionFailed(Self.setupMessage)
        }
        let result = try FileeDocumentConverter().convert(input: input, format: .hwp, directory: outputDirectory).output
        let signature = try FileHandle(forReadingFrom: result)
        defer { try? signature.close() }
        guard try signature.read(upToCount: 8) == Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) else {
            throw ConversionError.conversionFailed("생성된 파일이 HWP 바이너리 형식이 아닙니다.")
        }
        try verifyText(source: input, output: result, directory: outputDirectory, python: python)
        return result
    }

    func verifyText(source: URL, output: URL, directory: URL, python: URL) throws {
        do {
            _ = try ConversionProcess.run(
                executable: python,
                arguments: ["-c", Self.verifier, source.path, output.path], directory: directory
            )
        } catch {
            throw ConversionError.conversionFailed(
                "원문 글자 보존을 확인하지 못해 HWP 저장을 중단했습니다. 표·수식·머리말 등 지원하지 않는 요소가 있거나 문서가 손상되었는지 확인해 주세요."
            )
        }
    }

    // Independent DOCX/HWP Unicode text checker.
    static let verifier = #"""
    import io, json, logging, sys, unicodedata
    from collections import Counter
    from contextlib import closing
    from zipfile import ZipFile
    from lxml import etree
    from hwp5.xmlmodel import Hwp5File

    logging.disable(logging.CRITICAL)
    W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    M = 'http://schemas.openxmlformats.org/officeDocument/2006/math'

    def normalized(s):
        return ''.join(c for c in unicodedata.normalize('NFC', s) if not c.isspace())

    def source_paragraphs(path):
        paragraphs = []
        with ZipFile(path) as package:
            if package.testzip() is not None:
                raise ValueError('Invalid Word document')
            for name in package.namelist():
                if not (name == 'word/document.xml' or (name.startswith(('word/header', 'word/footer')) and name.endswith('.xml')) or name in ('word/footnotes.xml', 'word/endnotes.xml')):
                    continue
                root = etree.fromstring(package.read(name), etree.XMLParser(resolve_entities=False, no_network=True))
                for paragraph in root.iter('{%s}p' % W):
                    parts = []
                    for text in paragraph.iter():
                        if text.tag not in ('{%s}t' % W, '{%s}t' % M):
                            continue
                        # Ignore deleted text and avoid counting a nested textbox paragraph twice.
                        ancestors = list(text.iterancestors())
                        if any(a.tag == '{%s}del' % W for a in ancestors):
                            continue
                        nearest = next((a for a in ancestors if a.tag == '{%s}p' % W), None)
                        if nearest is paragraph:
                            parts.append(text.text or '')
                    value = normalized(''.join(parts))
                    if value:
                        paragraphs.append(value)
        return paragraphs

    def validate(source, output):
        expected = source_paragraphs(source)
        if not expected:
            raise ValueError('검사할 본문 글자가 없는 Word 문서입니다.')
        stream = io.BytesIO()
        with closing(Hwp5File(output)) as document:
            if document.header.version[0] != 5:
                raise ValueError('HWP 5 결과 파일이 아닙니다.')
            document.text.xmlevents().dump(stream)
        root = etree.fromstring(stream.getvalue(), etree.XMLParser(resolve_entities=False, no_network=True))
        actual = normalized(''.join(node.text or '' for node in root.iter('Text')))
        missing = Counter(''.join(expected)) - Counter(actual)
        if missing or any(p not in actual for p in expected):
            # Do not put document contents into application error messages or logs.
            raise ValueError('원문 글자 누락·변경이 감지되어 HWP 저장을 중단했습니다. 표·수식·머리말 등 지원하지 않는 요소가 있는지 확인해 주세요.')
        return {'verified': True, 'paragraphs': len(expected), 'characters': sum(map(len, expected))}

    if __name__ == '__main__':
        try:
            print(json.dumps(validate(sys.argv[1], sys.argv[2]), ensure_ascii=False))
        except Exception as e:
            print(str(e), file=sys.stderr)
            sys.exit(1)
    """#
}
