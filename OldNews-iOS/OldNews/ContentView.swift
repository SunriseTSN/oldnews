import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: OldNewsViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .tabItem { Label("聊天", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(0)
            PluginsView()
                .tabItem { Label("插件", systemImage: "puzzlepiece.extension.fill") }
                .tag(1)
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .background(OldNewsTheme.background.ignoresSafeArea())
        .toolbarBackground(OldNewsTheme.panel, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .alert("提示", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct ChatView: View {
    @EnvironmentObject private var model: OldNewsViewModel
    @State private var showingFileImporter = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(OldNewsTheme.divider)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if model.messages.isEmpty {
                            welcome
                        }
                        ForEach(model.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if model.isSending {
                            HStack(spacing: 10) {
                                ProgressView().tint(OldNewsTheme.accent)
                                Text("旧闻社正在处理任务…")
                                    .font(.subheadline)
                                    .foregroundStyle(OldNewsTheme.secondaryText)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .id("typing-indicator")
                        }
                    }
                    .padding(.vertical, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.count) { _, _ in
                    guard let last = model.messages.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onChange(of: model.isSending) { _, sending in
                    if sending { proxy.scrollTo("typing-indicator", anchor: .bottom) }
                }
            }
            if !model.pendingAttachments.isEmpty {
                pendingFiles
            }
            composer
        }
        .background(OldNewsTheme.background)
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): urls.forEach { model.addFile(from: $0) }
            case .failure(let error): model.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                for (index, item) in newItems.enumerated() {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                        model.addPhoto(data: data, filename: "图片-\(index + 1).\(ext)")
                    }
                }
                selectedPhotos = []
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(OldNewsTheme.accent.opacity(0.18))
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(OldNewsTheme.accent)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("旧闻社")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(OldNewsTheme.primaryText)
                Text("OldNews · v0.1.0 iOS")
                    .font(.caption2)
                    .foregroundStyle(OldNewsTheme.secondaryText)
            }
            Spacer(minLength: 4)
            Circle()
                .fill(model.isConnected ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(model.isConnected ? "已连接" : "未连接")
                .font(.caption2.weight(.medium))
                .foregroundStyle(OldNewsTheme.secondaryText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(OldNewsTheme.panel)
    }

    private var welcome: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 42))
                .foregroundStyle(OldNewsTheme.accent)
                .padding(.bottom, 4)
            Text("你好，今天有什么想做的？")
                .font(.title3.weight(.bold))
                .foregroundStyle(OldNewsTheme.primaryText)
            Text("可以直接说目标，例如：把这张图片转换成彩色 ASCII 图并生成 PNG 文件。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(OldNewsTheme.secondaryText)
                .frame(maxWidth: 330)
            HStack(spacing: 8) {
                suggestion("生成 ASCII 图", icon: "text.alignleft")
                suggestion("整理视频笔记", icon: "film")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 44)
    }

    private func suggestion(_ title: String, icon: String) -> some View {
        Button {
            model.draft = title == "生成 ASCII 图" ? "帮我把图片转换成彩色 ASCII 图，输出 PNG 和 TXT 文件。" : "帮我把这个视频整理成带时间戳的 Markdown 笔记。"
            composerFocused = true
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(OldNewsTheme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(OldNewsTheme.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(OldNewsTheme.primaryText)
    }

    private var pendingFiles: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.pendingAttachments) { file in
                    HStack(spacing: 7) {
                        Image(systemName: file.mimeType.hasPrefix("image/") ? "photo" : "doc.fill")
                            .foregroundStyle(OldNewsTheme.accent)
                        Text(file.name).lineLimit(1).frame(maxWidth: 150)
                        Button { model.removeAttachment(file.id) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(OldNewsTheme.secondaryText)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(OldNewsTheme.card)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(OldNewsTheme.background)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Menu {
                Button { showingFileImporter = true } label: { Label("选择文件", systemImage: "paperclip") }
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 6, matching: .images) {
                    Label("选择图片", systemImage: "photo")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(OldNewsTheme.secondaryText)
                    .frame(width: 30, height: 42)
            }
            TextField("给旧闻社一个任务…", text: $model.draft, axis: .vertical)
                .font(.body)
                .lineLimit(1...5)
                .focused($composerFocused)
                .submitLabel(.send)
                .onSubmit { Task { await model.send() } }
                .padding(.vertical, 10)
                .frame(minHeight: 42)
            Button {
                composerFocused = false
                Task { await model.send() }
            } label: {
                Image(systemName: model.isSending ? "hourglass" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 38, height: 38)
                    .background(canSend ? OldNewsTheme.accent : OldNewsTheme.accent.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .disabled(model.isSending || (model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.pendingAttachments.isEmpty))
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OldNewsTheme.composer)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(OldNewsTheme.divider, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .padding(.bottom, 9)
        .background(OldNewsTheme.background)
    }

    private var canSend: Bool {
        !model.isSending && (!model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.pendingAttachments.isEmpty)
    }
}

private struct MessageBubble: View {
    @EnvironmentObject private var model: OldNewsViewModel
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(OldNewsTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(OldNewsTheme.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            } else {
                Spacer(minLength: 36)
            }
            VStack(alignment: .leading, spacing: 10) {
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .foregroundStyle(OldNewsTheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(message.attachments) { attachment in
                    AttachmentRow(attachment: attachment)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(isUser ? OldNewsTheme.userBubble : OldNewsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(OldNewsTheme.divider.opacity(0.7), lineWidth: 1))
            if isUser {
                Image(systemName: "person.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(OldNewsTheme.primaryText.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(OldNewsTheme.divider)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            } else {
                Spacer(minLength: 20)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

private struct AttachmentRow: View {
    @EnvironmentObject private var model: OldNewsViewModel
    let attachment: ChatAttachment
    @State private var isDownloading = false
    @State private var downloadedFile: URL?
    @State private var downloadError: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 19))
                .foregroundStyle(OldNewsTheme.accent)
                .frame(width: 38, height: 38)
                .background(OldNewsTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(downloadError ?? (isDownloading ? "正在获取文件…" : "文件附件"))
                    .font(.caption2)
                    .foregroundStyle(downloadError == nil ? OldNewsTheme.secondaryText : Color.red)
                    .lineLimit(2)
            }
            Spacer(minLength: 2)
            if let downloadedFile {
                ShareLink(item: downloadedFile) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                }
            } else {
                Button {
                    Task { await download() }
                } label: {
                    if isDownloading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .disabled(isDownloading || attachment.downloadURL == nil)
            }
        }
        .padding(9)
        .background(OldNewsTheme.background.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var iconName: String {
        if attachment.mimeType?.hasPrefix("image/") == true { return "photo" }
        if attachment.mimeType?.hasPrefix("audio/") == true { return "waveform" }
        if attachment.mimeType?.hasPrefix("video/") == true { return "film" }
        if attachment.mimeType == "application/pdf" { return "doc.richtext" }
        return "doc.fill"
    }

    private func download() async {
        guard let path = attachment.downloadURL else { return }
        isDownloading = true
        downloadError = nil
        defer { isDownloading = false }
        do {
            downloadedFile = try await model.api.downloadAttachment(path: path, filename: attachment.name, baseURL: model.serverURL, token: model.accessToken)
        } catch {
            downloadError = error.localizedDescription
        }
    }
}
