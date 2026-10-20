import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

struct ImageConverter {
    func convert(input: URL, output: URL, format: SupportedFormat) throws {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let destination = CGImageDestinationCreateWithURL(
                output as CFURL, format.contentType.identifier as CFString, 1, nil
              ) else {
            throw ConversionError.conversionFailed("이미지 파일을 읽거나 출력 형식을 만들 수 없습니다.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.conversionFailed("이미지 변환에 실패했습니다.")
        }
    }
}
