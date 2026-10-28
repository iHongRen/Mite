#!/bin/bash
# 构建 dist/Mite.app：下载官方双架构二进制、合并、打包、内嵌、签名。
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"

VERSION="0.2.0"
BASE_URL="https://github.com/heydeer/homebrew-tap/releases/download/pngdeer-v${VERSION}"
ARM_URL="${BASE_URL}/pngdeer-${VERSION}-aarch64-apple-darwin.tar.gz"
X86_URL="${BASE_URL}/pngdeer-${VERSION}-x86_64-apple-darwin.tar.gz"
ARM_SHA="5e1745e08232d60a6050c611ed57521b8d0352e7f3a43d60d5ae2b4a79c073b8"
X86_SHA="5324df85d4b891b59f3f830ea68c03b4fb5157bc4591d10436854daf39c7d4f7"

BUILD=".build"
mkdir -p "$BUILD/arm" "$BUILD/x86" vendor dist

fetch() {
  local url="$1" sha="$2" dir="$3"
  if [ -x "$BUILD/$dir/pngdeer" ]; then
    echo "使用缓存: $BUILD/$dir"
    return
  fi
  echo "下载 ${url##*/}"
  curl -L --fail --silent --show-error -o "$BUILD/$dir.tar.gz" "$url"
  echo "$sha  $BUILD/$dir.tar.gz" | shasum -a 256 -c -
  tar -xzf "$BUILD/$dir.tar.gz" -C "$BUILD/$dir"
}

fetch "$ARM_URL" "$ARM_SHA" arm
fetch "$X86_URL" "$X86_SHA" x86

echo "合并为 Universal 二进制"
lipo -create "$BUILD/arm/pngdeer" "$BUILD/x86/pngdeer" -output vendor/pngdeer
chmod +x vendor/pngdeer
cp "$BUILD/arm/LICENSE" vendor/LICENSE
cp "$BUILD/arm/THIRD_PARTY_LICENSES.txt" vendor/THIRD_PARTY_LICENSES.txt

echo "打包应用"
rm -rf dist/Mite.app
osacompile -o dist/Mite.app src/app.applescript

# osacompile 不写 CFBundleIdentifier，补上后 TCC 才能按应用记录“控制访达”权限
PLIST="dist/Mite.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIdentifier" "$PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.cxy.Mite" "$PLIST"

RES="dist/Mite.app/Contents/Resources"
cp vendor/pngdeer "$RES/pngdeer"
cp src/main.sh "$RES/main.sh"
cp vendor/LICENSE "$RES/LICENSE-pngdeer"
cp vendor/THIRD_PARTY_LICENSES.txt "$RES/"
chmod +x "$RES/pngdeer" "$RES/main.sh"

echo "签名（ad-hoc）"
codesign --force --sign - "$RES/pngdeer" >/dev/null
codesign --force --deep --sign - --identifier com.cxy.Mite dist/Mite.app >/dev/null
codesign --verify --deep --strict dist/Mite.app

echo "生成发布包"
ditto -c -k --keepParent dist/Mite.app dist/Mite.zip

echo
echo "构建完成: $(pwd)/dist/Mite.app"
echo "发布包: $(pwd)/dist/Mite.zip"
lipo -info "$RES/pngdeer"
du -sh dist/Mite.app
