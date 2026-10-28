#!/bin/bash
# 发布脚本：构建 Mite.zip、打 tag、创建 GitHub Release 并上传安装包。
# 用法：./release.sh 0.1.0
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"

REPO="iHongRen/Mite"
VERSION="${1:-}"

if [ -z "$VERSION" ]; then
  echo "用法: ./release.sh <版本号>   例: ./release.sh 0.1.0" >&2
  exit 1
fi
VERSION="${VERSION#v}"
if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "版本号格式应为 x.y.z，收到: $1" >&2
  exit 1
fi
TAG="v$VERSION"

command -v gh >/dev/null 2>&1 || {
  echo "未安装 GitHub CLI，请先执行: brew install gh" >&2
  exit 1
}
gh auth status >/dev/null 2>&1 || {
  echo "GitHub CLI 未登录，请先执行: gh auth login" >&2
  exit 1
}

# 只允许从已推送的干净工作区发布，保证 Release 对应源码可追溯
if [ -n "$(git status --porcelain)" ]; then
  echo "工作区不干净，请先提交或清理后再发布：" >&2
  git status --short >&2
  exit 1
fi
git rev-parse --verify --quiet '@{u}' >/dev/null || {
  echo "当前分支没有上游分支，请先 push 到 GitHub。" >&2
  exit 1
}
if [ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}')" ]; then
  echo "本地分支与上游不一致，请先 push 或 pull。" >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "tag $TAG 已存在。" >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "远程已存在 tag $TAG。" >&2
  exit 1
fi

./build.sh "$VERSION"
if [ ! -f dist/Mite.zip ]; then
  echo "未生成 dist/Mite.zip。" >&2
  exit 1
fi

echo "打 tag $TAG 并推送"
git tag -a "$TAG" -m "Mite $VERSION"
git push origin "$TAG"

echo "创建 Release 并上传 dist/Mite.zip"
if ! gh release create "$TAG" dist/Mite.zip \
  --repo "$REPO" \
  --title "Mite $VERSION" \
  --generate-notes \
  --verify-tag; then
  echo "创建 Release 失败，回滚已推送的 tag。" >&2
  git push --delete origin "$TAG" >/dev/null 2>&1 || true
  git tag -d "$TAG" >/dev/null 2>&1 || true
  exit 1
fi

echo
echo "发布完成: https://github.com/$REPO/releases/tag/$TAG"
