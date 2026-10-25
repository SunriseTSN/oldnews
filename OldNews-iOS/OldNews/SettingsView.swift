import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: OldNewsViewModel
    @State private var statusMessage: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(OldNewsTheme.accent)
                            .frame(width: 48, height: 48)
                            .background(OldNewsTheme.accent.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("旧闻社 OldNews")
                                .font(.headline)
                            Text("iOS 客户端 · 0.1.0")
                                .font(.caption)
                                .foregroundStyle(OldNewsTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 6)
                    LabeledContent("连接状态") {
                        Label(model.isConnected ? "已连接" : "未连接", systemImage: model.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(model.isConnected ? .green : OldNewsTheme.secondaryText)
                            .font(.subheadline)
                    }
                } header: {
                    Text("应用")
                }

                Section {
                    TextField("https://your-domain.example", text: $model.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                    SecureField("可选：OldNews 访问令牌", text: $model.accessToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task {
                            isTesting = true
                            statusMessage = nil
                            await model.checkConnection()
                            statusMessage = model.isConnected ? "连接成功。" : model.connectionMessage
                            isTesting = false
                        }
                    } label: {
                        HStack {
                            if isTesting { ProgressView().controlSize(.small) }
                            Text(isTesting ? "正在测试…" : "测试服务器连接")
                            Spacer()
                            Image(systemName: "arrow.up.right.circle")
                        }
                    }
                    .disabled(isTesting || model.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(model.isConnected ? .green : .orange)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("OldNews Core")
                } footer: {
                    Text("填写 Ubuntu 服务器上的 OldNews Core 地址，而不是 DeepSeek API 地址。建议使用已启用 HTTPS 的域名。访问令牌由你的 OldNews 后端验证；不要把 DeepSeek API Key 填在这里。")
                }

                Section {
                    Label("DeepSeek API Key 应保存在 Ubuntu 后端。", systemImage: "lock.shield")
                    Label("聊天、插件和文件接口按 Docs/Backend-API.md 约定实现。", systemImage: "point.3.connected.trianglepath.dotted")
                    Label("未连接后端时，界面可浏览，但不能执行真实 AI 请求。", systemImage: "info.circle")
                } header: {
                    Text("安全与说明")
                }

                Section {
                    HStack {
                        Text("iOS 最低部署版本")
                        Spacer()
                        Text("iOS 17+")
                            .foregroundStyle(OldNewsTheme.secondaryText)
                    }
                    HStack {
                        Text("目标测试系统")
                        Spacer()
                        Text("iOS 27")
                            .foregroundStyle(OldNewsTheme.secondaryText)
                    }
                } header: {
                    Text("兼容性")
                } footer: {
                    Text("使用 Xcode 27 与 iOS 27 SDK 构建后，再在真实设备上验证系统外观、文件分享和网络连接。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(OldNewsTheme.background)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(OldNewsTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
