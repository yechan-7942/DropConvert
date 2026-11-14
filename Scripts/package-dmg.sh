#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/dist/DropConvert.app"
ARCH="$(uname -m)"
OUTPUT="$PROJECT_ROOT/dist/DropConvert-0.1.0-beta-$ARCH.dmg"
test -d "$APP_DIR" || { printf '먼저 Scripts/package-app.sh를 실행해 주세요.\n' >&2; exit 1; }
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/dropconvert-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM
ditto "$APP_DIR" "$STAGE/DropConvert.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/설치 안내.txt" <<'TEXT'
DropConvert 무료 테스트 버전

1. DropConvert.app을 Applications 폴더로 드래그합니다.
2. 응용 프로그램에서 DropConvert를 실행하고 메뉴 막대 아이콘을 누릅니다.
3. Word·HWP 변환은 ‘문서 변환 준비’ → ‘필요한 기능 설치’를 누릅니다.
   최초 설치에는 인터넷과 수백 MB의 추가 저장 공간이 필요합니다.
4. 파일을 선택하고 출력 형식을 고른 뒤 ‘변환하기’를 누릅니다.

문서는 외부에 업로드하지 않으며 원본은 수정하지 않습니다.
HWP 변환은 베타 기능입니다. 글꼴·표·수식·쪽 배치는 원본과 다를 수 있습니다.
문서 도구 자동 설치를 제공하며, YouTube 저장용 도구는 별도 설치가 필요합니다.

이 버전은 개발용 로컬 서명이며 Apple 공증은 적용하지 않았습니다.
다른 Mac의 설치·실행 검증과 정식 배포용 서명·공증은 별도 진행 예정입니다.
TEXT
hdiutil create -volname DropConvert -srcfolder "$STAGE" -ov -format UDZO "$OUTPUT"
hdiutil verify "$OUTPUT"
printf 'Created %s\n' "$OUTPUT"
