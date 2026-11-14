#!/usr/bin/env python3
"""Install a pinned, checksum-verified Filee portable engine without system integration."""
import argparse
import hashlib
import json
import platform
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
from pathlib import Path

VERSION = "2.4.0"
ARCHIVES = {
    "arm64": "a257eb796712a24ee58e3b33a1265d44d00e74121f3e276d4d6a2c880155577e",
    "x86_64": "df66108323715baa11ff88df001af7beea83eb5206b0064de02d1aceace72ed1",
}


def install(archive=None):
    machine = platform.machine()
    if platform.system() != "Darwin" or machine not in ARCHIVES:
        raise RuntimeError("이 설치 스크립트는 macOS Apple Silicon/Intel용입니다.")
    if not hasattr(tarfile, "data_filter"):
        raise RuntimeError("안전한 압축 해제를 위해 Python 3.12 이상이 필요합니다.")
    parent = Path.home() / "Library/Application Support/DropConvert/Engines"
    parent.mkdir(parents=True, exist_ok=True)
    destination = parent / "Filee"
    if destination.exists():
        raise RuntimeError("HWP 저장 엔진이 이미 있습니다. 기존 폴더를 백업·이동한 뒤 다시 실행해 주세요.")
    with tempfile.TemporaryDirectory(prefix="hwp-writer-", dir=parent) as temporary:
        work = Path(temporary)
        if archive is None:
            architecture = "arm64" if machine == "arm64" else "x64"
            filename = f"Filee-{VERSION}-osx-{architecture}.tar.gz"
            url = f"https://github.com/KnifeLemon/Filee/releases/download/v{VERSION}/{filename}"
            archive = work / filename
            print("공식 HWP 저장 엔진을 다운로드합니다…", flush=True)
            with urllib.request.urlopen(url, timeout=60) as response, archive.open("wb") as output:
                shutil.copyfileobj(response, output)
        archive = Path(archive).resolve()
        with archive.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        if digest != ARCHIVES[machine]:
            raise RuntimeError("배포 파일의 SHA256이 일치하지 않습니다. 설치를 중단합니다.")
        unpacked = work / "unpacked"
        with tarfile.open(archive) as package:
            package.extractall(unpacked, filter="data")
        applications = list(unpacked.rglob("Filee.app"))
        if len(applications) != 1:
            raise RuntimeError("배포 파일에서 Filee.app을 찾을 수 없습니다.")
        package_root = applications[0].parent
        cli = applications[0] / "Contents/MacOS/filee-cli"
        rhwp = cli.parent / "engines/rhwp/rhwp"
        if not cli.is_file() or not rhwp.is_file():
            raise RuntimeError("배포 파일에 CLI 또는 HWP 쓰기 엔진이 없습니다.")
        # Never run the package's install.sh or GUI: no login item, Finder service or PATH changes.
        result = subprocess.run([str(cli), "version"], capture_output=True, text=True, timeout=30, check=True)
        print(result.stdout.strip())
        (package_root / "dropconvert-engine.json").write_text(json.dumps({
            "version": VERSION, "sha256": digest,
            "source": "https://github.com/KnifeLemon/Filee",
        }, indent=2))
        shutil.move(str(package_root), destination)
    print(f"HWP 저장 엔진 설치 완료: {destination}")
    print("글자 보존 검사용 pyhwp도 필요합니다: sh Scripts/install-hwp-engine.sh")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="이미 다운로드한 공식 배포 파일")
    args = parser.parse_args()
    install(args.archive)
