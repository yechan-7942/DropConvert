# 외부 도구와 라이선스 고지

DropConvert 앱은 Apple의 시스템 프레임워크를 사용합니다. 문서 변환 도구는 별도 프로세스로 실행하며,
필요할 때 공식 배포처에서 사용자 전용 폴더에 설치합니다. 이 목록은 각 도구에 포함된 원본 라이선스 고지를 대체하지 않습니다.

| 도구 | 용도 | 버전 / 라이선스 / 출처 |
|---|---|---|
| Filee | DOCX 읽기, HWPX·DOCX 쓰기, 변환 경로 실행 | 2.4.0 / MIT / [프로젝트](https://github.com/KnifeLemon/Filee), [라이선스](https://github.com/KnifeLemon/Filee/blob/v2.4.0/LICENSE), [하위 구성요소 고지](https://github.com/KnifeLemon/Filee/blob/v2.4.0/THIRD-PARTY-NOTICES.md) |
| rhwp | Filee 배포본에 포함된 HWP 쓰기·렌더링 도구 | MIT / [프로젝트](https://github.com/edwardkim/rhwp) |
| uv | 별도 Python 환경과 패키지 설치 | 0.12.12 / MIT 또는 Apache-2.0 / [프로젝트](https://github.com/astral-sh/uv) |
| Python | 문서 파서 실행 환경 | 3.12.14 / [라이선스](https://docs.python.org/3.12/license.html), [관리형 배포 출처](https://github.com/astral-sh/python-build-standalone) |
| pyhwp | HWP 읽기, DOCX → HWP의 별도 글자 보존 검사 | 0.1b15 / AGPL-3.0-or-later / [프로젝트와 라이선스](https://github.com/mete0r/pyhwp) |
| lxml·six 및 Python 하위 의존성 | pyhwp 실행 | 각 배포 패키지의 라이선스·저작권 고지 참조 |
| LibreOffice | 이미 설치된 경우 문서 변환에 사용 | MPL-2.0 등 / [라이선스 안내](https://www.libreoffice.org/about-us/licenses/) |
| yt-dlp·ffmpeg | 선택 기능인 YouTube 저장, 사용자가 별도 설치 | [yt-dlp](https://github.com/yt-dlp/yt-dlp), [FFmpeg](https://ffmpeg.org/legal.html)의 각 배포본 고지 참조 |

Filee 배포 파일의 `LICENSE`, `THIRD-PARTY-NOTICES.md`와 엔진 폴더를 유지합니다.
Filee에는 위 표 외에도 여러 구성요소가 포함되며 해당 배포본의 원본 고지가 기준입니다.
uv와 Python 패키지도 설치된 배포본의 고지를 확인할 수 있습니다.

DropConvert 자체의 별도 오픈소스 라이선스는 아직 지정하지 않았습니다.
