import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Security

@MainActor
final class OldNewsViewModel: ObservableObject {
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "oldnews.serverURL") }
    }
    @Published var accessToken: String {
        didSet { SecureTokenStore.save(accessToken) }
    }
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "你好，我是旧闻社。\n\n连接你的 OldNews 服务器后，我就能帮你调用插件、处理文件，并把生成结果直接交还给你。", attachments: [])
    ]
    @Published var draft = ""
    @Published var pendingAttachments: [PendingAttachment] = []
    @Published var isSending = false
    @Published var isCheckingConnection = false
    @Published var isConnected = false
    @Published var connectionMessage = "尚未连接服务器"
    @Published var errorMessage: String?
    @Published var conversationID: String?

    let api = OldNewsAPI()

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "oldnews.serverURL") ?? ""
        self.accessToken = SecureTokenStore.load()
    }

    func checkConnection() async {
        isCheckingConnection = true
        defer { isCheckingConnection = false }
        do {
            try await api.checkHealth(baseURL: serverURL, token: accessToken)
            isConnected = true
            connectionMessage = "服务器已连接"
        } catch {
            isConnected = false
            connectionMessage = error.localizedDescription
        }
    }

    func addFile(from sourceURL: URL) {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: sourceURL)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("OldNewsUploads", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let safeName = "\(UUID().uuidString.prefix(8))_\(sourceURL.lastPathComponent)"
            let destination = folder.appendingPathComponent(safeName)
            try data.write(to: destination, options: .atomic)
            let type = UTType(filenameExtension: sourceURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            pendingAttachments.append(PendingAttachment(fileURL: destination, name: sourceURL.lastPathComponent, mimeType: type))
        } catch {
            errorMessage = "无法读取文件：\(error.localizedDescription)"
        }
    }

    func addPhoto(data: Data, filename: String) {
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("OldNewsUploads", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = filename.isEmpty ? "图片-\(UUID().uuidString.prefix(8)).jpg" : filename
            let destination = folder.appendingPathComponent("\(UUID().uuidString.prefix(8))_\(name)")
            try data.write(to: destination, options: .atomic)
            pendingAttachments.append(PendingAttachment(fileURL: destination, name: name, mimeType: "image/jpeg"))
        } catch {
            errorMessage = "无法保存图片：\(error.localizedDescription)"
        }
    }

    func removeAttachment(_ id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty, !isSending else { return }
        guard !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请先在“设置”中填写 OldNews 服务器地址。"
            return
        }

        let selectedFiles = pendingAttachments
        pendingAttachments = []
        draft = ""
        let localAttachments = selectedFiles.map { ChatAttachment(id: "local-\($0.id.uuidString)", name: $0.name, mimeType: $0.mimeType) }
        messages.append(ChatMessage(role: .user, content: text, attachments: localAttachments))
        isSending = true
        defer { isSending = false }

        do {
            var uploadedIDs: [String] = []
            for item in selectedFiles {
                let result = try await api.upload(fileURL: item.fileURL, baseURL: serverURL, token: accessToken)
                uploadedIDs.append(result.id)
            }
            let result = try await api.sendChat(message: text, conversationID: conversationID, attachmentIDs: uploadedIDs, baseURL: serverURL, token: accessToken)
            conversationID = result.conversationID ?? conversationID
            let reply = result.reply ?? result.message ?? "任务已执行，但服务器没有返回文字内容。"
            messages.append(ChatMessage(role: .assistant, content: reply, attachments: result.attachments ?? []))
        } catch {
            messages.append(ChatMessage(role: .assistant, content: "这次请求没有完成。\n\n\(error.localizedDescription)\n\n请确认 OldNews 后端已启动，并且接口符合 Docs/Backend-API.md 中的约定。", attachments: []))
        }
    }
}


private enum SecureTokenStore {
    private static let service = Bundle.main.bundleIdentifier ?? "com.sunrisesn.oldnews"
    private static let account = "oldnews.accessToken"

    static func load() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return "" }
        return token
    }

    static func save(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !token.isEmpty, let data = token.data(using: .utf8) else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
