import SwiftUI

struct PluginsView: View {
    @EnvironmentObject private var model: OldNewsViewModel
    @State private var plugins: [ServerPlugin] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedPlugin: ServerPlugin?
    @State private var showingRunPrompt = false
    @State private var argumentsText = ""
    @State private var isRunning = false
    @State private var runResult: String?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("工具与插件")
                            .font(.largeTitle.bold())
                            .foregroundStyle(OldNewsTheme.primaryText)
                        Text("插件在 OldNews 服务器上执行。你也可以直接在聊天中描述目标，由 AI 选择合适的工具。")
                            .font(.subheadline)
                            .foregroundStyle(OldNewsTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)

                    HStack(spacing: 8) {
                        Circle().fill(model.isConnected ? Color.green : Color.orange).frame(width: 8, height: 8)
                        Text(model.isConnected ? "服务器已连接" : "尚未连接服务器")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Button {
                            Task { await loadPlugins() }
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                        }
                        .disabled(isLoading)
                    }
                    .foregroundStyle(OldNewsTheme.secondaryText)

                    if isLoading {
                        ProgressView("正在获取插件列表…")
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if let loadError {
                        ContentUnavailableView {
                            Label("无法加载插件", systemImage: "puzzlepiece.extension")
                        } description: {
                            Text(loadError)
                        } actions: {
                            Button("重试") { Task { await loadPlugins() } }
                                .buttonStyle(.borderedProminent)
                        }
                    } else if plugins.isEmpty {
                        ContentUnavailableView {
                            Label("还没有插件", systemImage: "puzzlepiece.extension")
                        } description: {
                            Text("连接已实现 /api/plugins 接口的 OldNews Core 后，这里会显示服务器可用的插件。")
                        } actions: {
                            Button("重新加载") { Task { await loadPlugins() } }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(plugins) { plugin in
                                PluginCard(plugin: plugin, isRunning: isRunning && selectedPlugin?.id == plugin.id) {
                                    selectedPlugin = plugin
                                    argumentsText = ""
                                    showingRunPrompt = true
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("建议的插件能力", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundStyle(OldNewsTheme.primaryText)
                        Text("图像与 ASCII 生成 · 视频笔记 · RSS 新闻 · 音乐检索 · 文件处理")
                            .font(.subheadline)
                            .foregroundStyle(OldNewsTheme.secondaryText)
                        Text("上面这些是规划方向，不代表你的服务器已经安装了这些插件。实际列表以 Core 返回的数据为准。")
                            .font(.caption)
                            .foregroundStyle(OldNewsTheme.secondaryText)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OldNewsTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(OldNewsTheme.divider, lineWidth: 1))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(OldNewsTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadPlugins() }
            .alert("运行插件", isPresented: $showingRunPrompt) {
                TextField("输入任务参数（可选）", text: $argumentsText)
                Button("运行") {
                    guard let plugin = selectedPlugin else { return }
                    Task { await run(plugin) }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("\(selectedPlugin?.name ?? "插件")将由 OldNews 服务器执行。请勿提交不信任的命令或敏感数据。")
            }
            .alert("插件结果", isPresented: Binding(get: { runResult != nil }, set: { if !$0 { runResult = nil } })) {
                Button("完成", role: .cancel) { runResult = nil }
            } message: {
                Text(runResult ?? "")
            }
        }
    }

    private func loadPlugins() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            plugins = try await model.api.loadPlugins(baseURL: model.serverURL, token: model.accessToken)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func run(_ plugin: ServerPlugin) async {
        isRunning = true
        defer { isRunning = false }
        do {
            runResult = try await model.api.runPlugin(id: plugin.id, argumentsText: argumentsText, baseURL: model.serverURL, token: model.accessToken)
        } catch {
            runResult = "执行失败：\(error.localizedDescription)"
        }
    }
}

private struct PluginCard: View {
    let plugin: ServerPlugin
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: plugin.icon ?? "puzzlepiece.extension.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OldNewsTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(OldNewsTheme.accent.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                Spacer(minLength: 0)
                Circle()
                    .fill((plugin.enabled ?? true) ? Color.green : Color.gray)
                    .frame(width: 7, height: 7)
            }
            Text(plugin.name)
                .font(.headline)
                .foregroundStyle(OldNewsTheme.primaryText)
                .lineLimit(2)
            Text(plugin.description)
                .font(.caption)
                .foregroundStyle(OldNewsTheme.secondaryText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
            Button(action: action) {
                HStack {
                    if isRunning { ProgressView().controlSize(.small) }
                    Text(isRunning ? "执行中" : "运行")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(OldNewsTheme.accent.opacity((plugin.enabled ?? true) ? 1 : 0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!(plugin.enabled ?? true) || isRunning)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OldNewsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(OldNewsTheme.divider, lineWidth: 1))
    }
}
