#!/bin/bash
# Mite：批量压缩 PNG，输出 PNG 或 WebP。压缩由同目录内嵌的 pngdeer 完成。
set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN="$SCRIPT_DIR/pngdeer"
CONFIG="$HOME/.config/mite/config"
LOG_DIR="$HOME/Library/Logs"
LOG="$LOG_DIR/Mite.log"

FORMAT="png"
TARGET="auto"
NOTIFY="none"
OUTPUT_NAME="tinified"
OPEN_OUTPUT="1"

[ -f "$CONFIG" ] && . "$CONFIG"

# 环境变量优先于配置文件
FORMAT="${MITE_FORMAT:-$FORMAT}"
TARGET="${MITE_TARGET:-$TARGET}"
NOTIFY="${MITE_NOTIFY:-$NOTIFY}"
OUTPUT_NAME="${MITE_OUTPUT_DIR:-$OUTPUT_NAME}"
OPEN_OUTPUT="${MITE_OPEN_OUTPUT:-$OPEN_OUTPUT}"

case "$FORMAT" in png|webp) ;; *) FORMAT="png" ;; esac
case "$NOTIFY" in dialog|notification|none) ;; *) NOTIFY="none" ;; esac
if [ "$TARGET" != "auto" ] && ! printf '%s' "$TARGET" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; then
  TARGET="auto"
fi
case "$OPEN_OUTPUT" in 0|1) ;; *) OPEN_OUTPUT="1" ;; esac
[ -n "$OUTPUT_NAME" ] || OUTPUT_NAME="tinified"

mkdir -p "$LOG_DIR" 2>/dev/null || true
log() { printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG" 2>/dev/null || true; }

as_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

notify() {
  local title message t m
  title="$1"
  message="$2"
  [ "$NOTIFY" = "none" ] && return 0
  t=$(as_escape "$title")
  m=$(as_escape "$message")
  if [ "$NOTIFY" = "dialog" ]; then
    osascript -e "display dialog \"$m\" buttons {\"好\"} default button 1 with title \"$t\"" >/dev/null 2>&1 || true
  else
    osascript -e "display notification \"$m\" with title \"$t\"" >/dev/null 2>&1 || true
  fi
}

human_size() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1048576) printf "%.1f MB", b / 1048576;
    else if (b >= 1024) printf "%.0f KB", b / 1024;
    else printf "%d B", b;
  }'
}

usage() {
  echo "用法: main.sh <PNG 文件或文件夹> ..."
  echo "配置: $CONFIG"
  echo "环境变量: MITE_FORMAT=png|webp  MITE_TARGET=auto|0-100"
  echo "          MITE_NOTIFY=dialog|notification|none"
  echo "          MITE_OUTPUT_DIR=tinified  MITE_OPEN_OUTPUT=0|1"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac
if [ $# -eq 0 ]; then
  usage
  exit 1
fi
if [ ! -x "$BIN" ]; then
  log "未找到 pngdeer: $BIN"
  notify "Mite" "未找到内嵌的 pngdeer 二进制：$BIN"
  exit 1
fi

tmp_files=$(mktemp) || exit 1
tmp_map=$(mktemp) || exit 1
tmp_dirs=$(mktemp) || exit 1
trap 'rm -f "$tmp_files" "$tmp_map" "$tmp_dirs"' EXIT

# 收集 PNG：目录递归查找，文件只接受 .png（pngdeer 只能解码 PNG）
for arg in "$@"; do
  [ -n "$arg" ] || continue
  case "$arg" in *.app) continue ;; esac
  if [ -d "$arg" ]; then
    while IFS= read -r -d '' f; do
      printf '%s\n' "$f" >> "$tmp_files"
    done < <(find "$arg" -type f -iname '*.png' -print0)
  elif [ -f "$arg" ]; then
    lower=$(printf '%s' "$arg" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
      *.png) printf '%s\n' "$arg" >> "$tmp_files" ;;
      *) log "跳过（不是 PNG）: $arg" ;;
    esac
  else
    log "跳过（不存在）: $arg"
  fi
done

sort -u "$tmp_files" -o "$tmp_files"
files=()
while IFS= read -r f; do
  files+=("$f")
done < "$tmp_files"
total=${#files[@]}

if [ "$total" -eq 0 ]; then
  log "没有找到可处理的 PNG"
  notify "Mite" "没有找到可处理的 PNG 图片"
  exit 0
fi

# 每个源目录对应一个本次新建的输出目录：tinified、tinified(1)……
for f in "${files[@]}"; do
  dirname "$f"
done | sort -u > "$tmp_dirs"

while IFS= read -r d; do
  out="$d/$OUTPUT_NAME"
  n=1
  while [ -d "$out" ]; do
    out="$d/$OUTPUT_NAME($n)"
    n=$((n + 1))
  done
  printf '%s\t%s\n' "$d" "$out" >> "$tmp_map"
  mkdir -p "$out" 2>/dev/null || true
done < "$tmp_dirs"

get_outdir() {
  local needle="$1" d o
  while IFS=$'\t' read -r d o; do
    if [ "$d" = "$needle" ]; then
      printf '%s' "$o"
      return 0
    fi
  done < "$tmp_map"
}

ok=0
kept=0
failed=0
saved=0
last_outdir=""

for f in "${files[@]}"; do
  d=$(dirname "$f")
  outdir=$(get_outdir "$d")
  [ -n "$outdir" ] || continue
  base=$(basename "$f")
  stem="${base%.*}"
  out="$outdir/$stem.$FORMAT"
  last_outdir="$outdir"

  if [ "$TARGET" = "auto" ]; then
    "$BIN" "$f" -o "$out" --format "$FORMAT" >/dev/null 2>&1
  else
    "$BIN" "$f" -o "$out" --format "$FORMAT" --target "$TARGET" >/dev/null 2>&1
  fi
  status=$?

  if [ "$status" -ne 0 ] || [ ! -f "$out" ]; then
    rm -f "$out"
    failed=$((failed + 1))
    log "失败: $f"
    continue
  fi

  src_size=$(stat -L -f%z "$f" 2>/dev/null || echo 0)
  out_size=$(stat -f%z "$out" 2>/dev/null || echo 0)

  if [ "$out_size" -lt "$src_size" ]; then
    ok=$((ok + 1))
    saved=$((saved + src_size - out_size))
    log "成功: $f -> $out ($(human_size "$src_size") -> $(human_size "$out_size"))"
  elif [ "$FORMAT" = "png" ]; then
    # PNG 输出没有变小：用原图替换，保证输出目录内容完整
    cp -p "$f" "$out" 2>/dev/null
    kept=$((kept + 1))
    log "保持原图: ${f}（压缩后 $(human_size "$out_size") 不小于原图 $(human_size "$src_size")）"
  else
    # WebP 输出反而更大：不生成该文件，保留源文件
    rm -f "$out"
    kept=$((kept + 1))
    log "保持原图: ${f}（WebP $(human_size "$out_size") 不小于原图 $(human_size "$src_size")）"
  fi
done

# 清理本次创建但没有任何输出的空目录
while IFS=$'\t' read -r d out; do
  [ -d "$out" ] && rmdir "$out" 2>/dev/null
done < "$tmp_map"

if [ -n "$last_outdir" ] && [ -d "$last_outdir" ] && [ "$OPEN_OUTPUT" = "1" ]; then
  open "$last_outdir" >/dev/null 2>&1 || true
fi

summary="共 ${total} 张：成功 ${ok} 张，保持原图 ${kept} 张"
[ "$failed" -gt 0 ] && summary="${summary}，失败 ${failed} 张"
[ "$saved" -gt 0 ] && summary="${summary}；节省 $(human_size "$saved")"

log "完成: $summary"
notify "Mite 压缩完成" "$summary"
exit 0
