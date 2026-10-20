# DropConvert

로컬에서 동작하는 macOS 파일 변환 유틸리티입니다. Swift 6, SwiftUI, AppKit, PDFKit, ImageIO를 사용하며 원본 파일은 수정하지 않습니다.

## Phase 1 MVP

- Finder에서 파일을 드래그하거나 파일 선택기로 추가
- 파일 형식 자동 감지
- PDF → PNG/JPG (첫 페이지 렌더링)
- PNG/JPG/HEIC/TIFF/BMP → PDF
- PNG/JPG/HEIC/TIFF/BMP 상호 변환
- DOCX → PDF (Homebrew LibreOffice 설치 시)
- 중복 파일명 자동 회피 (`name (2).ext`)
- 변환 파일을 원본과 같은 폴더에 저장

PDF 다중 페이지 변환, 페이지 선택, OCR, Office 포맷 확장은 다음 단계에서 추가합니다. 현재 PDF → 이미지 MVP는 첫 페이지만 출력하며, 품질·레이아웃 손실이 있을 수 있습니다.

## 실행

Xcode 15 이상에서 `Package.swift`를 열고 `DropConvert` 스킴을 실행하세요.

DOCX → PDF를 사용하려면 별도로 LibreOffice를 설치해야 합니다.

```sh
brew install --cask libreoffice
```

현재 환경에 Xcode가 설치되어 있지 않다면 `xcode-select --install`은 명령줄 도구만 설치하므로, macOS 앱 빌드에는 Xcode 본체가 필요합니다.
