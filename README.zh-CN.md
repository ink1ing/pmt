# PMT

版本：`v0.0.33`

[English README](./README.md)

PMT 是一个轻量的 macOS 原生应用，目标是在任意输入框中选中文字后，通过一个全局快捷键，把内容快速改写成结构化提示词。

当前版本聚焦一个核心流程：

1. 在任意可编辑输入区域选中文字。
2. 按下全局快捷键。
3. PMT 自动复制选中内容，通过当前配置的模型渠道完成改写，再原地粘贴替换。

## 功能

- 基于 Swift、SwiftUI、AppKit 构建的 macOS 原生应用。
- 支持跨应用的选中文本改写工作流。
- 默认快捷键：`Ctrl + X`。
- 支持模型渠道配置：自定义 OpenAI-compatible 端点，或 GitHub OAuth 接入 Copilot。
- 支持读取模型列表、选择模型、测试模型延迟。
- 支持内置 `简洁`、`常规` 提示词模式，以及 `自定义` 提示词模式。
- 顶部状态栏图标可选开启。
- 面板内置日志，可查看热键、权限、API 请求和改写结果。
- API Key 存储在本地配置中。
- 支持 OpenAI-compatible 的 `/models` 与 `/chat/completions` 接口。
- 支持 GitHub OAuth device flow 授权 GitHub Copilot 模型。
- 支持中英文界面切换。
- 支持通过 Sparkle 在 App 内检查并安装更新。

## 项目结构

- `Sources/PMT`：应用源码。
- `scripts/build-app.sh`：构建 `dist/PMT.app`。
- `dist/PMT.app`：打包后的应用。

## 运行

```sh
swift run PMT
```

## 打包

```sh
./scripts/build-app.sh
open dist/PMT.app
```

## 发布更新

PMT 使用 Sparkle 做 App 内更新。应用内置的更新 feed 地址是：

```txt
https://raw.githubusercontent.com/ink1ing/pmt/main/appcast.xml
```

构建发布 zip 并重新生成 Sparkle appcast：

```sh
scripts/package-release.sh 0.0.21 21
```

然后将 `release/appcast/PMT-0.0.21.zip` 上传到 GitHub Release tag `v0.0.21`，再提交并推送生成的 `appcast.xml`。

## 权限

PMT 完整运行需要以下 macOS 权限：

- `辅助功能`：用于激活目标应用并发送复制或粘贴快捷键。
- `输入监控`：用于在其他应用获得焦点时接收全局快捷键。

设置面板中已经提供这些权限的检查与请求按钮。

## API 兼容性

当前版本支持两个模型渠道：

- 自定义端点：OpenAI-compatible API。
- GitHub OAuth：GitHub Copilot OAuth 授权、模型读取和聊天补全。

自定义端点使用：

- `GET {endpoint}/models`
- `POST {endpoint}/chat/completions`

默认端点：

```txt
https://api.openai.com/v1
```

只要网关提供兼容接口，也可以接入自定义服务或本地模型服务。

## 当前状态

`v0.0.33` 已经包含核心改写闭环、统一保存、模型延迟测试、内置 Prompt 模式、可折叠日志、中英文界面切换，以及最新的单列设置布局。
