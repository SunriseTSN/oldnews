# OldNews iOS 客户端（0.1.0）

这是一个基于现有 OldNews 视觉方向制作的原生 SwiftUI iOS 工程，不是从 Windows 安装包直接转换出来的。它采用深色风格，并将桌面端侧栏改为适合 iPhone 的底部标签页。

## 当前包含

- 聊天主界面、用户/助手消息气泡、任务执行状态。
- 从照片图库选择图片，或通过系统文件选择器发送文件。
- 通过 OldNews Core 上传附件，并在助手回复中提供文件下载/分享入口。
- 插件列表、插件快速调用入口。
- 服务器地址、可选访问令牌和连接测试。
- 不在 iPhone 客户端保存 DeepSeek API Key；AI 请求应由 Ubuntu 上的 OldNews Core 转发。

## 重要说明

- 这里提供的是 **Xcode 源工程**，不是已签名、已验证可安装的 IPA。
- 当前执行环境是 Linux，没有 Apple 的 iOS SDK、Xcode 或 Apple 签名证书，因此无法在这里编译、签名并验证真实 iPhone 安装包。
- 你上传的 `OldNews-Setup-0.1.0.exe` 是 Windows NSIS 安装包，不是 iOS 源码；不能安全地直接“转换”为 IPA。
- iOS 客户端需要一个实现 `Docs/Backend-API.md` 约定的 OldNews Core 后端。你现有 Windows 程序是否已经提供这些 API，尚未验证；若没有，需要在 Ubuntu 上实现/适配这些接口。
- 这是第一版连接型客户端骨架。实际真机测试、流式回复、历史会话同步、图片预览和完整鉴权需要根据现有 Core 的真实接口继续联调。

## 构建环境

当前 Apple 官方工具链说明：Xcode 27 提供 iOS 27 SDK，并要求 macOS Tahoe 26.6 或更新版本。工程最低部署目标设为 iOS 17，因此在合适的 Xcode 版本下也可面向较早系统编译；是否在 iOS 27 真机上工作，仍需实机验证。

1. 在 Mac 上安装符合要求的 Xcode，并打开 `OldNews.xcodeproj`。
2. 进入 Target → Signing & Capabilities，选择自己的 Team；必要时改成自己拥有的 Bundle Identifier（默认 `com.sunrisesn.oldnews`）。
3. 用 iOS 27 模拟器运行 UI，随后连接 iPhone 进行签名安装测试。
4. 在应用“设置”里填写 OldNews Core 的 HTTPS 地址和访问令牌。
5. 只有当后端 API 全部按 `Docs/Backend-API.md` 实现后，聊天、插件和附件处理才会完成真实端到端工作。

## 不使用自己的 Mac：通过 GitHub Actions 构建未签名 IPA

工程包含 `.github/workflows/build-unsigned-ipa.yml`。把整个目录推送到自己的 GitHub 仓库后，打开仓库的 **Actions → Build unsigned OldNews IPA → Run workflow**，成功后下载 `OldNews-unsigned-IPA` artifact。

这个 workflow 生成的是**未签名 IPA**，不是可直接安装的成品。可尝试用 SideStore/AltStore 等工具在安装时签名；能否安装还取决于签名工具、设备注册和当前 iOS 限制。不要把未签名 IPA 当成已经完成真机验证的正式版本。

## 在 Mac 上构建并签名 IPA

在已配置 Apple 开发签名的 macOS 终端里运行：

```bash
cd OldNews-iOS
export APPLE_TEAM_ID="你的 Apple Team ID"
./build-ipa-macos.sh
```

脚本默认导出 development IPA，供签名配置允许的测试设备安装。分发到 App Store/TestFlight 需要使用对应的分发方式与 Apple 账号配置；IPA 不是免签名文件，不能保证直接双击安装。

## 项目结构

```text
OldNews-iOS/
├── OldNews.xcodeproj/
├── OldNews/
│   ├── OldNewsApp.swift
│   ├── ContentView.swift
│   ├── PluginsView.swift
│   ├── SettingsView.swift
│   ├── OldNewsAPI.swift
│   ├── OldNewsViewModel.swift
│   ├── Models.swift
│   ├── OldNewsTheme.swift
│   └── Assets.xcassets/
├── Docs/
│   ├── Backend-API.md
│   └── ExportOptions.plist.template
├── .github/workflows/build-unsigned-ipa.yml
└── build-ipa-macos.sh
```
