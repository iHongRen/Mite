#!/bin/sh
# Mite 安装脚本：从 GitHub Releases 下载 Mite.zip 并安装到 /Applications。
# 用法：curl -fsSL https://raw.githubusercontent.com/iHongRen/Mite/main/install.sh | sh
set -eu

REPO="iHongRen/Mite"
APP="Mite"
INSTALL_DIR="/Applications"
ZIP_URL="https://github.com/${REPO}/releases/latest/download/${APP}.zip"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Mite 仅支持 macOS。" >&2
  exit 1
fi

for cmd in curl ditto xattr mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "缺少命令：$cmd" >&2
    exit 1
  fi
done

if [ ! -w "$INSTALL_DIR" ]; then
  echo "没有写入 $INSTALL_DIR 的权限，请用 sudo 重新运行。" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "下载 ${APP}.zip"
if ! curl -fL --progress-bar -o "$TMP/$APP.zip" "$ZIP_URL"; then
  echo "下载失败，请确认 ${REPO} 已发布 ${APP}.zip。" >&2
  exit 1
fi

ditto -x -k "$TMP/$APP.zip" "$TMP/out"
if [ ! -d "$TMP/out/$APP.app" ]; then
  echo "压缩包中未找到 ${APP}.app。" >&2
  exit 1
fi

# 退出正在运行的旧版本，避免覆盖时文件忙
pkill -x "$APP" 2>/dev/null || true

echo "安装到 $INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP.app"
cp -R "$TMP/out/$APP.app" "$INSTALL_DIR/$APP.app"

# 去掉下载隔离标记，避免首次启动被 Gatekeeper 拦截
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP.app"

echo
echo "安装完成：$INSTALL_DIR/$APP.app"
echo "按住 ⌘ 把 $APP.app 拖到 Finder 工具栏，选中 PNG 文件或文件夹后点击图标即可压缩。"
