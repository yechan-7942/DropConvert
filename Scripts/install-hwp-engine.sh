#!/bin/sh
set -eu

# Separate local tool environment; no system Python or LibreOffice settings changed.
if ! command -v uv >/dev/null 2>&1; then
    printf 'uv가 필요합니다: brew install uv\n' >&2
    exit 1
fi
uv tool install --python 3.12 --with 'lxml>=5,<7' --with 'six==1.17.0' 'pyhwp==0.1b15'
printf 'HWP 엔진 설치 완료. LibreOffice도 설치되어 있어야 합니다.\n'
