#!/bin/sh
# Mite 安装脚本：从 GitHub Releases 下载 Mite.zip 并安装到 /Applications。
# 用法：curl -fsSL https://raw.githubusercontent.com/iHongRen/Mite/main/install.sh | sh
set -eu

REPO="iHongRen/Mite"
APP="Mite"
INSTALL_DIR="/Applications"
ZIP_URL="https://github.com/${REPO}/releases/latest/download/${APP}.zip"

# 用 sudo 安装时，配置要写到真实用户的家目录
if [ -n "${SUDO_USER:-}" ]; then
  USER_HOME=$(eval echo "~$SUDO_USER")
else
  USER_HOME="$HOME"
fi

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
# 先复制到临时名再替换，避免中途失败留下残缺的 App
NEW="$INSTALL_DIR/.${APP}.app.new"
rm -rf "$NEW"
cp -R "$TMP/out/$APP.app" "$NEW"
rm -rf "$INSTALL_DIR/$APP.app"
mv "$NEW" "$INSTALL_DIR/$APP.app"

# 去掉下载隔离标记，避免首次启动被 Gatekeeper 拦截
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP.app"

# 生成默认配置，已有配置不覆盖
CONFIG_DIR="$USER_HOME/.config/mite"
CONFIG_FILE="$CONFIG_DIR/config"
if [ -f "$CONFIG_FILE" ]; then
  echo "保留已有配置：$CONFIG_FILE"
else
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<'CONFIG'
# Mite 配置
# 环境变量 MITE_FORMAT / MITE_TARGET / MITE_NOTIFY /
# MITE_OUTPUT_DIR / MITE_OPEN_OUTPUT 优先于本文件。

# 输出格式：png 或 webp
FORMAT=png

# 压缩质量：auto 自动选择，或 0-100 的 SSIMULACRA2 目标
TARGET=auto

# 提示方式：dialog 弹窗 / notification 系统通知 / none 静默
NOTIFY=none

# 输出目录名，位于每个源文件所在目录下
OUTPUT_NAME=tinified

# 完成后是否打开输出目录：1 是 / 0 否
OPEN_OUTPUT=1
CONFIG
  if [ -n "${SUDO_USER:-}" ]; then
    chown "$SUDO_USER" "$CONFIG_FILE"
  fi
  echo "已生成默认配置：$CONFIG_FILE"
fi

echo
echo "安装完成：$INSTALL_DIR/$APP.app"
echo "按住 ⌘ 把 $APP.app 拖到 Finder 工具栏，选中 PNG 文件或文件夹后点击图标即可压缩。"
