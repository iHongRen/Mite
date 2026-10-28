# Mite

macOS 上的本地批量 PNG 压缩工具。在 Finder 里选中图片或文件夹，点一下工具栏图标就能压缩。压缩由内嵌的 [pngdeer](https://github.com/heydeer/pngdeer) 在本机完成——图片不会上传。

## 特点

- **本地离线**：内嵌 pngdeer 二进制，不依赖网络或外部安装
- **批量处理**：单个文件、多个文件、整个文件夹（递归）
- **两种输出**：PNG（默认，画质目标约 85–90）或 WebP（体积更小，画质目标约 70）
- **不会变大**：压缩结果不小于原图时保留原图
- **Universal 二进制**：Apple Silicon 与 Intel 都可用

## 安装

在终端执行：

```bash
curl -fsSL https://raw.githubusercontent.com/iHongRen/Mite/main/install.sh | sh
```

脚本会把最新版本安装到 `/Applications`，并在 `~/.config/mite/config` 生成一份默认配置。若提示没有写入权限，用 `sudo sh` 重新执行即可。

也可以从 [Releases](https://github.com/iHongRen/Mite/releases) 下载 `Mite.zip` 手动安装：解压后把 `Mite.app` 拖入 `/Applications`，再执行一次 `xattr -dr com.apple.quarantine /Applications/Mite.app` 去掉隔离标记。

## 使用

1. 按住 `⌘`，把 `/Applications/Mite.app` 拖到 Finder 工具栏
2. 在 Finder 中选中 PNG 文件、多个文件或整个文件夹
3. 点击工具栏上的 Mite 图标

压缩结果保存在**每个源目录**下的 `tinified/` 文件夹里；若同名文件夹已存在，依次为 `tinified(1)`、`tinified(2)`……。压缩完成后默认会自动打开输出目录（一次涉及多个目录时除外，避免弹出多个窗口）。

首次点击会弹出“控制访达”权限请求，请选择允许。如果误点了拒绝，到 **系统设置 → 隐私与安全性 → 自动化 → Mite** 勾选“访达”即可。

> 点击 Finder 工具栏图标时，系统不会把选中的文件作为参数传给应用，所以应用需要向 Finder 查询当前选中项——这就是必须授予“控制访达”权限的原因。

## 配置

配置文件在 `~/.config/mite/config`，安装脚本会自动生成一份带注释的默认配置（已存在则不覆盖），直接编辑即可。手动安装时没有这份文件，可以从仓库复制示例：

```bash
mkdir -p ~/.config/mite
cp config.example ~/.config/mite/config
```

| 配置项 | 说明 | 默认 |
|---|---|---|
| `FORMAT` | 输出格式：`png` 或 `webp` | `png` |
| `TARGET` | 质量目标：`auto` 自动选择，或 0–100 的 SSIMULACRA2 分数 | `auto` |
| `NOTIFY` | 提示方式：`dialog` 弹窗 / `notification` 系统通知 / `none` 静默 | `none` |
| `OUTPUT_NAME` | 输出目录名 | `tinified` |
| `OPEN_OUTPUT` | 完成后是否打开输出目录：`1` 是 / `0` 否 | `1` |

也可以用环境变量临时覆盖同名配置：`MITE_FORMAT`、`MITE_TARGET`、`MITE_NOTIFY`、`MITE_OUTPUT_DIR`、`MITE_OPEN_OUTPUT`。

配置在每次运行时读取，改完立即生效，不需要重新安装或构建。


## 限制

- **输入只支持 PNG**。pngdeer 只能解码 PNG；WebP 是输出格式，不是输入格式。拖入的 JPG/WebP 等会被跳过。
- WebP 的自动质量目标是面向 TinyPNG WebP 的约 70 分，明显低于 PNG 路径的 85–90，因此体积小很多，但可能出现可见的画质损失。需要高质量时保持 `FORMAT=png`。
- 扫描目录时会跳过 `.app` 应用包和已生成的 `tinified`/`tinified(n)` 目录，不会压缩应用内的图标，也不会把上次的压缩结果再压一遍。
- 压缩耗时与图片尺寸相关，所有核都会参与；大图可能需要几秒到几十秒。

## 常见问题

**点击工具栏图标仍提示“请先在 Finder 中选中 PNG 图片或文件夹”？**

- 确认 Finder 窗口处于前台，且确实选中了文件或文件夹
- 检查 **系统设置 → 隐私与安全性 → 自动化 → Mite** 是否勾选了“访达”
- 替换过 App 后，需要把新的 `Mite.app` 重新拖到 Finder 工具栏，旧图标可能仍指向旧副本

**点击图标没反应，也没有输出目录？**

先看 `~/Library/Logs/Mite.log` 最后的记录，通常会写明原因（例如没有找到 PNG、输出目录无法创建）。

## 其他选择

如果你想压缩 JPG、WebP、AVIF 等 PNG 以外的格式，可以试试 [TinyImage](https://github.com/iHongRen/TinyImage)：它调用 Tinify 云端 API，格式支持更广，但需要申请 API Key，免费额度为每月 500 张，图片也会上传到云端。只想处理 PNG、且希望完全本地离线的话，用 Mite 就够了。

