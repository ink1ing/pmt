# PMT

版本：`v0.0.1`

[English README](./README.md)

PMT 是一个轻量的 macOS 原生应用，目标是在任意输入框中选中文字后，通过一个全局快捷键，把内容快速改写成结构化提示词。

当前版本聚焦一个核心流程：

1. 在任意可编辑输入区域选中文字。
2. 按下全局快捷键。
3. PMT 自动复制选中内容，通过 OpenAI-compatible API 完成改写，再原地粘贴替换。

## 功能

- 基于 Swift、SwiftUI、AppKit 构建的 macOS 原生应用。
- 支持跨应用的选中文本改写工作流。
- 默认快捷键：`Ctrl + X`。
- 支持配置 API 端点、API Key、读取模型列表、选择模型、测试连接。
- 支持编辑系统提示词，并提供快捷改写模式。
- 顶部状态栏图标可选开启。
- 面板内置日志，可查看热键、权限、API 请求和改写结果。
- API Key 存储在 Keychain。
- 支持 OpenAI-compatible 的 `/models` 与 `/chat/completions` 接口。

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

## 权限

PMT 完整运行需要以下 macOS 权限：

- `辅助功能`：用于激活目标应用并发送复制或粘贴快捷键。
- `输入监控`：用于在其他应用获得焦点时接收全局快捷键。
- `通知`：用于显示错误通知。

设置面板中已经提供这些权限的检查与跳转按钮。

## API 兼容性

当前版本面向 OpenAI-compatible API：

- `GET {endpoint}/models`
- `POST {endpoint}/chat/completions`

默认端点：

```txt
https://api.openai.com/v1
```

只要网关提供兼容接口，也可以接入自定义服务或本地模型服务。

## 当前状态

`v0.0.1` 是 PMT 的第一个可用版本，已经包含核心改写闭环、设置面板、API 配置、权限检查和应用打包能力。
