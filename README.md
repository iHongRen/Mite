# Mite

macOS 上的本地批量 PNG 压缩工具，用法类似 [TinyImage](https://github.com/iHongRen/TinyImage)：在 Finder 中选中图片或文件夹，点击工具栏图标即可压缩。压缩由内嵌的 [pngdeer](https://github.com/heydeer/pngdeer) 在本地完成，图片不会上传，也没有额度和 API Key。

## 特点

- **本地离线**：内嵌 pngdeer 二进制，不依赖网络或外部安装
- **批量处理**：支持单个文件、多个文件、整个文件夹（递归）
- **两种输出**：PNG（默认，画质目标约 85–90）或 WebP（体积更小，画质目标约 70）
- **不会变大**：压缩结果不小于原图时保留原图
- **Universal 二进制**：Apple Silicon 与 Intel 都可用

## 构建

需要 macOS 自带的 `curl`、`lipo`、`osacompile`、`codesign`：

```bash
./build.sh
```

产物是 `dist/Mite.app`，已内嵌双架构 pngdeer（约 4 MB），同时生成可发布的 `dist/Mite.zip`。

## 发布

需要一次性安装并登录 [GitHub CLI](https://cli.github.com/)：

```bash
brew install gh
gh auth login
```

之后在干净的、已推送到 GitHub 的分支上执行：

```bash
./release.sh 0.1.0
```

脚本会依次构建、打 `v0.1.0` tag 并推送、创建 Release 并上传 `dist/Mite.zip`（Release notes 由提交记录自动生成）。`install.sh` 始终下载 `releases/latest`，发布后无需改动。

## 安装与使用

一键安装（从 GitHub Releases 下载最新版本到 `/Applications`）：

```bash
curl -fsSL https://raw.githubusercontent.com/iHongRen/Mite/main/install.sh | sh
```

也可以自行构建后手动安装：执行 `./build.sh` 生成 `dist/Mite.app`，将它拖到 `/Applications`。

1. 按住 `⌘` 用鼠标把 `/Applications/Mite.app` 拖到 Finder 工具栏
2. 在 Finder 中选中 PNG 文件或文件夹，点击工具栏上的 Mite 图标
3. 压缩结果保存在每个源目录下的 `compressed/` 文件夹（已存在则依次为 `compressed(1)`、`compressed(2)`……）

首次点击会请求“控制访达”权限（用于读取当前选中的文件），请选择允许。如果误点了拒绝，到 **系统设置 → 隐私与安全性 → 自动化 → Mite**，勾选“访达”即可。

> Finder 工具栏点击图标时，系统不会把选中的文件作为参数传给应用，所以 `on run` 会主动向 Finder 查询当前选中项。这也是必须授予“控制访达”权限的原因。

> 应用使用 ad-hoc 签名，未做 Apple 公证。安装脚本会自动执行 `xattr -dr com.apple.quarantine`；如果是手动把 App 拷到其他机器，可能需要自行执行：
> `xattr -dr com.apple.quarantine /Applications/Mite.app`

## 配置

复制配置示例并编辑：

```bash
mkdir -p ~/.config/mite
cp config.example ~/.config/mite/config
```

| 配置项 | 说明 | 默认 |
|---|---|---|
| `FORMAT` | 输出格式：`png` 或 `webp` | `png` |
| `TARGET` | 质量目标：`auto` 或 0–100 的 SSIMULACRA2 分数 | `auto` |
| `NOTIFY` | 提示方式：`dialog` 弹窗 / `notification` 通知 / `none` 静默 | `notification` |
| `OUTPUT_NAME` | 输出目录名 | `compressed` |
| `OPEN_OUTPUT` | 完成后是否打开输出目录 | `1` |

也可以用同名环境变量覆盖：`MITE_FORMAT`、`MITE_TARGET`、`MITE_NOTIFY`、`MITE_OUTPUT_DIR`、`MITE_OPEN_OUTPUT`。

配置在每次运行时读取，修改后无需重新构建应用。

## 命令行使用

应用内的脚本也可以直接运行，便于调试或配合 Automator：

```bash
# 处理单个文件
Mite.app/Contents/Resources/main.sh image.png

# 处理文件夹，输出 WebP，不弹提示
MITE_FORMAT=webp MITE_NOTIFY=none Mite.app/Contents/Resources/main.sh ./images

# 指定固定质量
MITE_TARGET=85 Mite.app/Contents/Resources/main.sh image.png
```

运行日志：`~/Library/Logs/Mite.log`

## 常见问题

**点击工具栏图标仍提示“请先在 Finder 中选中 PNG 图片或文件夹”？**

- 确认 Finder 窗口处于前台，且确实选中了文件或文件夹
- 检查 **系统设置 → 隐私与安全性 → 自动化 → Mite** 是否勾选了“访达”
- 替换过 App 后，需要把新的 `Mite.app` 重新拖到 Finder 工具栏，旧图标可能仍指向旧副本

## 限制

- **输入只支持 PNG**。pngdeer 只能解码 PNG；WebP 是输出格式，不是输入格式。拖入的 JPG/WebP 等会被跳过。
- WebP 的自动质量目标是面向 TinyPNG WebP 的约 70 分，明显低于 PNG 路径的 85–90，因此体积小很多，但可能出现可见的画质损失。需要高质量时保持 `FORMAT=png`。
- 压缩耗时与图片尺寸相关，所有核都会参与；大图可能需要几秒到几十秒。

## 目录结构

```
Mite/
├── install.sh            # 一键安装脚本（下载 Release）
├── build.sh              # 构建应用与发布包
├── release.sh            # 打 tag 并发布 GitHub Release
├── config.example        # 配置示例
├── src/
│   ├── main.sh           # 批量压缩逻辑
│   └── app.applescript   # Finder 入口外壳
├── vendor/               # 构建时生成：universal 二进制与许可证
└── dist/                 # 构建产物：Mite.app、Mite.zip
```

发布新版本时执行 `./release.sh <版本号>`，脚本会构建并自动上传到 GitHub Release。

## 许可证

本项目代码可自由使用。内嵌的 pngdeer 为 MIT 许可证，其第三方依赖许可见应用内 `Contents/Resources/THIRD_PARTY_LICENSES.txt`。
