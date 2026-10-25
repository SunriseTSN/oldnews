import Foundation

struct ChatAttachment: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let mimeType: String?
    let downloadURL: String?
    let previewURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case mimeType = "mime_type"
        case downloadURL = "download_url"
        case previewURL = "preview_url"
    }

    init(id: String, name: String, mimeType: String? = nil, downloadURL: String? = nil, previewURL: String? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.downloadURL = downloadURL
        self.previewURL = previewURL
    }
}

struct ChatMessage: Identifiable {
    enum Role: Equatable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let content: String
    let attachments: [ChatAttachment]
    let date = Date()
}

struct PendingAttachment: Identifiable {
    let id = UUID()
    let fileURL: URL
    let name: String
    let mimeType: String
}

struct ServerPlugin: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String?
    let enabled: Bool?
}

struct PluginListResponse: Decodable {
    let plugins: [ServerPlugin]
}

struct ChatRequest: Encodable {
    let message: String
    let conversationID: String?
    let attachmentIDs: [String]

    enum CodingKeys: String, CodingKey {
        case message
        case conversationID = "conversation_id"
        case attachmentIDs = "attachment_ids"
    }
}

struct ChatResponse: Decodable {
    let reply: String?
    let message: String?
    let conversationID: String?
    let attachments: [ChatAttachment]?

    enum CodingKeys: String, CodingKey {
        case reply, message, attachments
        case conversationID = "conversation_id"
    }
}

struct UploadResponse: Decodable {
    let id: String
    let name: String?
    let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case mimeType = "mime_type"
    }
}

struct PluginRunRequest: Encodable {
    let arguments: [String: String]
}

struct PluginRunResponse: Decodable {
    let message: String?
    let output: String?
}
