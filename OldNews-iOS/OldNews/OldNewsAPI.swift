import Foundation

struct OldNewsAPI {
    enum APIError: LocalizedError {
        case invalidServerURL
        case invalidResponse
        case http(Int, String)
        case missingDownloadURL

        var errorDescription: String? {
            switch self {
            case .invalidServerURL:
                return "服务器地址无效。请在“设置”中填写 https:// 开头的地址。"
            case .invalidResponse:
                return "服务器返回了无法识别的响应。请检查 OldNews 后端接口。"
            case .http(let code, let detail):
                return "服务器请求失败（HTTP \(code)）：\(detail)"
            case .missingDownloadURL:
                return "服务器没有返回附件下载地址。"
            }
        }
    }

    private func makeURL(_ path: String, baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed),
              let scheme = base.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              base.host != nil else {
            throw APIError.invalidServerURL
        }
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return base.appendingPathComponent(cleanPath)
    }

    private func request(_ path: String, method: String = "GET", baseURL: String, token: String, body: Data? = nil, contentType: String? = "application/json") throws -> URLRequest {
        let url = try makeURL(path, baseURL: baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }

    private func checkedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "未知错误"
            throw APIError.http(http.statusCode, String(body.prefix(240)))
        }
        return data
    }

    func checkHealth(baseURL: String, token: String) async throws {
        let req = try request("/health", baseURL: baseURL, token: token)
        _ = try await checkedData(for: req)
    }

    func sendChat(message: String, conversationID: String?, attachmentIDs: [String], baseURL: String, token: String) async throws -> ChatResponse {
        let payload = ChatRequest(message: message, conversationID: conversationID, attachmentIDs: attachmentIDs)
        let body = try JSONEncoder().encode(payload)
        let req = try request("/api/chat", method: "POST", baseURL: baseURL, token: token, body: body)
        return try JSONDecoder().decode(ChatResponse.self, from: await checkedData(for: req))
    }

    func upload(fileURL: URL, baseURL: String, token: String) async throws -> UploadResponse {
        let boundary = "OldNewsBoundary-\(UUID().uuidString)"
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent.replacingOccurrences(of: "\"", with: "")
        let mimeType = Self.mimeType(for: fileURL)
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendUTF8("\r\n--\(boundary)--\r\n")

        let req = try request("/api/files", method: "POST", baseURL: baseURL, token: token, body: body, contentType: "multipart/form-data; boundary=\(boundary)")
        return try JSONDecoder().decode(UploadResponse.self, from: await checkedData(for: req))
    }

    func loadPlugins(baseURL: String, token: String) async throws -> [ServerPlugin] {
        let req = try request("/api/plugins", baseURL: baseURL, token: token)
        let data = try await checkedData(for: req)
        if let wrapped = try? JSONDecoder().decode(PluginListResponse.self, from: data) {
            return wrapped.plugins
        }
        if let direct = try? JSONDecoder().decode([ServerPlugin].self, from: data) {
            return direct
        }
        throw APIError.invalidResponse
    }

    func runPlugin(id: String, argumentsText: String, baseURL: String, token: String) async throws -> String {
        let args = argumentsText.isEmpty ? [:] : ["input": argumentsText]
        let body = try JSONEncoder().encode(PluginRunRequest(arguments: args))
        let safeID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let req = try request("/api/plugins/\(safeID)/run", method: "POST", baseURL: baseURL, token: token, body: body)
        let data = try await checkedData(for: req)
        let result = try? JSONDecoder().decode(PluginRunResponse.self, from: data)
        return result?.output ?? result?.message ?? (String(data: data, encoding: .utf8) ?? "插件执行完成。")
    }

    func resolve(_ path: String?, baseURL: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if let url = URL(string: path), url.scheme != nil { return url }
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let fragment = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: trimmed + fragment)
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "txt": return "text/plain"
        case "md", "markdown": return "text/markdown"
        case "pdf": return "application/pdf"
        case "mp4": return "video/mp4"
        case "mp3": return "audio/mpeg"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}

extension OldNewsAPI {
    func downloadAttachment(path: String, filename: String, baseURL: String, token: String) async throws -> URL {
        let url: URL
        if let absolute = URL(string: path), absolute.scheme != nil {
            url = absolute
        } else {
            guard let base = URL(string: baseURL), let resolved = URL(string: path, relativeTo: base)?.absoluteURL else {
                throw APIError.invalidServerURL
            }
            url = resolved
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 90
        if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let data = try await checkedData(for: req)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("OldNewsDownloads", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeName = URL(fileURLWithPath: filename).lastPathComponent
        let output = folder.appendingPathComponent(safeName.isEmpty ? "OldNews-附件" : safeName)
        try data.write(to: output, options: .atomic)
        return output
    }
}
