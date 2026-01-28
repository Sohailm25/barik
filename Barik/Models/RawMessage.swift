// ABOUTME: Raw message from messaging providers (iMessage, Gmail).
// ABOUTME: Unified format before LLM processing into DigestItems.

import Foundation

struct RawMessage: Identifiable, Codable, Equatable {
    let id: String
    let source: String
    let sender: String
    let body: String
    let timestamp: Date
    let conversationName: String?

    init(
        id: String,
        source: String,
        sender: String,
        body: String,
        timestamp: Date,
        conversationName: String? = nil
    ) {
        self.id = id
        self.source = source
        self.sender = sender
        self.body = body
        self.timestamp = timestamp
        self.conversationName = conversationName
    }
}
