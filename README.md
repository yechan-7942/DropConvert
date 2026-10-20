# DropConvert

DropConvert는 Finder에서 파일을 끌어다 놓고 원하는 형식을 선택하면, 파일을
웹사이트에 업로드하지 않고 Mac에서 직접 변환하는 **SwiftUI 기반 macOS 파일
변환 앱**입니다.

문서, 이미지, PDF를 변환할 때마다 여러 웹 서비스나 앱을 찾아야 하는 불편을
줄이고, 원본 파일과 개인정보를 외부로 보내지 않는 것을 목표로 시작했습니다.
변환 결과는 기본적으로 원본 파일 옆에 저장하며, 원본은 수정하지 않습니다.


## 왜 만들었는가

일반적인 파일 변환은 다음과 같은 문제가 있습니다.

- 형식마다 다른 웹사이트나 프로그램을 찾아야 합니다.
- 파일을 외부 서비스에 업로드해야 하는 경우가 있습니다.
- 지원하지 않는 변환도 가능한 것처럼 표시되는 경우가 있습니다.
- 같은 이름의 결과 파일이 원본을 덮어쓸 수 있습니다.
- 변환 품질 저하나 레이아웃 변경을 미리 알기 어렵습니다.

DropConvert는 이 문제를 다음 원칙으로 해결합니다.

1. **로컬 우선**: 가능한 변환은 Foundation과 macOS 기본 프레임워크로 처리합니다.
2. **기능을 과장하지 않음**: 입력 형식과 변환 엔진을 확인한 뒤 가능한 출력 형식만 표시합니다.
3. **원본 보호**: 원본을 변경하지 않고 중복 파일명도 자동으로 피합니다.
4. **모듈화**: 형식 감지, 지원 형식 판단, 변환 실행, 출력 파일 관리를 분리합니다.
5. **제한사항 공개**: 손실 가능성, 첫 페이지만 변환되는 기능 등을 README와 UI에서 명확히 알립니다.

## 현재 구현된 기능

### 입력과 파일 처리

- Finder 파일 선택
- 파일 드래그 앤 드롭
- Uniform Type Identifiers(UTType)를 이용한 파일 형식 감지
- 원본 파일 보존
- 원본과 같은 폴더에 결과 저장
- 같은 이름의 파일이 있으면 `name (2).ext`, `name (3).ext`처럼 새 이름 사용
- 한국어 파일명과 경로 지원을 고려한 URL 기반 파일 처리

### Phase 1 변환

| 입력 | 출력 | 구현 방식 |
|---|---|---|
| PDF | PNG, JPG | PDFKit으로 첫 페이지 렌더링 후 ImageIO로 저장 |
| PNG, JPG, HEIC, TIFF, BMP | PDF | PDFKit의 이미지 페이지 생성 |
| PNG, JPG, HEIC, TIFF, BMP | PNG, JPG | ImageIO/Core Graphics |
| DOCX | PDF | LibreOffice headless가 설치된 경우 |

출력 형식은 `ConversionRegistry`가 입력 파일의 UTType과 사용 가능한 변환
엔진을 확인하여 동적으로 결정합니다. 따라서 현재 환경에서 실제로 처리할 수
없는 형식을 UI에 지원되는 것처럼 표시하지 않습니다.

## 현재 제한사항

정확한 동작 범위를 숨기지 않기 위해 다음 사항을 명시합니다.

- PDF → 이미지 변환은 현재 **첫 페이지만** 출력합니다.
- 여러 페이지를 각각 이미지로 내보내거나 페이지를 선택하는 기능은 아직 없습니다.
- 현재 UI는 한 번에 한 파일을 선택해 변환합니다.
- OCR, PDF → DOCX, DOC/DOCX의 양방향 변환은 아직 구현되지 않았습니다.
- PPT/PPTX, XLS/XLSX, CSV, ODT, HTML, Markdown 변환은 아직 구현되지 않았습니다.
- 이미지와 PDF 사이의 변환은 문서 편집 구조나 레이아웃을 보존하는 변환이 아닙니다.
- DOCX → PDF는 LibreOffice가 설치되어 있고 실행 가능한 경우에만 제공됩니다.

## 설계와 구현 방법

Swift 6의 Swift Package 구조를 사용하고, 앱 계층은 MVVM에 맞춰 분리했습니다.
외부 유료 API나 필수 클라우드 서비스는 사용하지 않습니다.

```text
DropConvert/
├── Package.swift
├── Sources/DropConvert/
│   ├── DropConvertApp.swift
│   ├── Models/
│   │   └── ConversionModels.swift
│   ├── Views/
│   │   └── ContentView.swift
│   ├── ViewModels/
│   │   └── ConversionViewModel.swift
│   └── Services/
│       ├── ConversionManager.swift
│       ├── ConversionRegistry.swift
│       ├── FileTypeDetector.swift
│       ├── FileOutputManager.swift
│       ├── ImageConverter.swift
│       ├── PDFConverter.swift
│       └── LibreOfficeConverter.swift
└── Tests/DropConvertTests/
    └── FileOutputManagerTests.swift
```

각 구성 요소의 역할은 다음과 같습니다.

- `FileTypeDetector`: 파일 URL에서 UTType을 감지합니다.
- `ConversionRegistry`: 입력 형식과 설치된 엔진을 기준으로 출력 형식을 결정합니다.
- `ConversionManager`: 적절한 변환 경로를 선택하고 변환을 실행합니다.
- `ImageConverter`: ImageIO/Core Graphics 기반 이미지 변환을 담당합니다.
- `PDFConverter`: PDFKit 기반 PDF 렌더링과 이미지 → PDF 변환을 담당합니다.
- `LibreOfficeConverter`: 설치된 LibreOffice를 격리된 임시 디렉터리에서 headless로 실행합니다.
- `FileOutputManager`: 원본 옆의 안전한 출력 경로와 중복 회피 이름을 생성합니다.
- `ConversionViewModel`: 파일 선택, 형식 선택, 변환 상태와 오류를 관리합니다.
- `ContentView`: 드래그 앤 드롭, 형식 선택, 진행 상태와 결과 UI를 제공합니다.

DOCX 변환 시에는 임시 디렉터리를 사용하여 LibreOffice가 원본 폴더에 중간
파일을 만들지 않도록 했고, 변환이 끝나면 임시 디렉터리를 정리합니다.

## 요구 환경

- macOS 13 이상
- Swift 6
- Xcode 15 이상 권장
- DOCX → PDF를 사용하려면 LibreOffice 추가 설치

`swift` 명령만 제공하는 Command Line Tools 환경에서는 SwiftUI 매크로 플러그인
(`SwiftUIMacros`)을 찾지 못해 앱 빌드가 실패할 수 있습니다. macOS 앱을
빌드하고 실행하려면 Xcode 본체가 필요합니다.

## 설치와 실행

### 1. 저장소 받기

```sh
git clone https://github.com/yechan-7942/DropConvert.git
cd DropConvert
```

### 2. Xcode에서 실행하기

`Package.swift`는 일반 Swift 소스 파일이 아니므로 `swift Package.swift`처럼
직접 실행하지 않습니다. Xcode가 패키지 설정을 읽어 앱을 빌드합니다.

```sh
open Package.swift
```

Xcode가 열리면 다음 순서로 실행합니다.

1. Scheme에서 `DropConvert` 선택
2. 실행 대상에서 `My Mac` 선택
3. `⌘R` 또는 상단의 실행 버튼 클릭
4. 앱에 파일을 끌어다 놓거나 **파일 선택** 클릭
5. 출력 형식을 선택하고 **변환하기** 클릭

Xcode가 설치된 경로가 올바른지 확인하려면 다음 명령을 사용합니다.

```sh
xcode-select -p
xcodebuild -version
```

Command Line Tools가 선택되어 있다면 Xcode 설치 후 다음처럼 변경합니다.

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### 3. LibreOffice 설치하기

DOCX → PDF 변환이 필요할 때만 설치합니다.

```sh
brew install --cask libreoffice
```

앱은 다음 경로에서 LibreOffice 실행 파일을 찾습니다.

- `/opt/homebrew/bin/libreoffice`
- `/usr/local/bin/libreoffice`

## Xcode 없이 앱으로 실행하기

개발 중에는 Xcode의 `⌘R`로 실행할 수 있지만, Xcode를 종료한 뒤에도 사용하려면
macOS 앱 번들로 패키징해야 합니다. 저장소의 패키징 스크립트가 Swift 실행 파일과
`Info.plist`를 `DropConvert.app` 구조로 묶고 로컬 서명합니다.

```sh
cd ~/Desktop/Yechan/Project/DropConvert
./Scripts/package-app.sh
open dist/DropConvert.app
```

생성된 앱을 응용 프로그램 폴더에 설치하려면 Finder에서 `dist/DropConvert.app`을
`응용 프로그램`으로 드래그하세요. 터미널에서는 다음처럼 복사할 수 있습니다.

```sh
cp -R dist/DropConvert.app /Applications/
open /Applications/DropConvert.app
```

이 앱은 개발용 로컬 서명으로 만들어집니다. 공개 배포를 위해서는 Apple Developer
서명과 공증(notarization)이 추가로 필요합니다.

## 개발자용 명령

패키지 설정만 확인할 때는 다음 명령을 사용합니다.

```sh
swift package dump-package
```

Xcode가 올바르게 설치된 환경에서는 다음 명령으로 빌드와 테스트를 수행할 수
있습니다.

```sh
swift build
swift test
```

현재 테스트는 출력 파일명이 이미 존재할 때 자동으로 새 이름을 만드는 동작을
검증합니다. 실제 macOS 앱 실행과 SwiftUI 빌드는 Xcode 환경에서 확인해야 합니다.
