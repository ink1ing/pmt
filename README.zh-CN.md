# PMT

版本：`v0.0.87`

[English README](./README.md)

PMT 是一个轻量的 macOS 原生应用，目标是在任意输入框中，通过全局快捷键把选中文本或语音听写内容快速改写成结构化提示词。

## 核心流程

选中文本改写：

1. 在任意可编辑输入区域选中文字。
2. 按下改写快捷键。
3. PMT 自动复制选中内容，通过当前配置的模型渠道完成改写，再原地粘贴替换。

预览语音听写：

1. 按下语音快捷键开始录音。
2. 再次按下同一个快捷键结束录音。
3. PMT 使用本地 WhisperKit 转写语音，只调用一次当前远程模型进行结构化改写，并把结果粘贴到当前光标位置。

很短的语音内容会直接插入原文，不触发模型改写。

## 功能

- 基于 Swift、SwiftUI、AppKit 构建的 macOS 原生应用。
- 支持跨应用的选中文本改写工作流。
- 默认改写快捷键：`Ctrl + X`。
- 支持自定义 OpenAI-compatible 端点。
- 支持 GitHub OAuth 认证并接入 GitHub Copilot。
- 支持读取全量模型列表、选择模型、测试模型延迟。
- 支持内置提示词风格和自定义提示词。
- 支持 Apple Silicon / M 芯片的预览语音听写功能。
- 使用 WhisperKit 本地转写，提供 `Base` 和 `Small` 两种模型。
- 语音转写支持 M 芯片 Metal 加速。
- 支持语音录入和模型改写的两步工作流。
- 听写和模型处理阶段提供不同的旋转状态 icon。
- 支持开始录音和结束录音提示音。
- 支持顶部状态栏图标，并更新了应用 icon。
- 面板内置日志，可查看热键、权限、模型请求和改写结果。
- 支持中英文界面切换。
- 支持通过 Sparkle 在 App 内检查并安装更新。

## 项目结构

- `Sources/PMT`：应用源码。
- `Resources`：应用 icon 资源。
- `scripts/build-app.sh`：构建 `dist/PMT.app`。
- `scripts/package-release.sh`：构建发布 ZIP、DMG 和 Sparkle appcast。
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

构建 Sparkle 更新 ZIP、用户下载用 DMG，并重新生成 Sparkle appcast：

```sh
scripts/package-release.sh 0.0.87 87
```

然后将两个文件都上传到对应的 GitHub Release tag：

- `release/appcast/PMT-0.0.87.zip`：用于 Sparkle App 内更新。
- `release/downloads/PMT-0.0.87.dmg`：用于普通用户下载安装。

最后提交并推送生成的 `appcast.xml`。

## 权限

PMT 完整运行需要以下 macOS 权限：

- `辅助功能`：用于激活目标应用并发送复制或粘贴快捷键。
- `输入监控`：用于在其他应用获得焦点时接收全局快捷键。
- `麦克风`：用于开启预览语音听写时录音。

设置面板中已经提供这些权限的检查与请求按钮。

## API 兼容性

当前版本支持两个模型渠道：

- OpenAI-compatible 端点：读取模型列表和聊天补全。
- GitHub OAuth：GitHub Copilot device flow 授权、全量模型读取和聊天补全。

自定义端点使用：

- `GET {endpoint}/models`
- `POST {endpoint}/chat/completions`

默认端点：

```txt
https://api.openai.com/v1
```

只要网关提供兼容接口，也可以接入自定义服务或本地模型服务。

## 当前状态

`v0.0.87` 简化了权限检查返回，顶部就绪状态增加应用版本号，更新了使用说明文案，并稳定 ad-hoc 签名身份，避免后续更新反复触发 macOS 权限重授。
