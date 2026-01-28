// ABOUTME: Aggregated digest item from messages and calendar events.
// ABOUTME: Contains LLM-extracted action items with priority for notch drawer display.

import Foundation

struct DigestItem: Identifiable, Equatable {
    let id: UUID
    let source: DigestSource
    let title: String
    let body: String?
    let actionItems: [ActionItem]
    let timestamp: Date
    let priority: ActionItem.Priority

    init(
        id: UUID = UUID(),
        source: DigestSource,
        title: String,
        body: String? = nil,
        actionItems: [ActionItem] = [],
        timestamp: Date,
        priority: ActionItem.Priority = .normal
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.body = body
        self.actionItems = actionItems
        self.timestamp = timestamp
        self.priority = priority
    }

    enum DigestSource: String, CaseIterable, Equatable {
        case imessage
        case gmail
        case calendar

        var displayName: String {
            switch self {
            case .imessage: return "iMessage"
            case .gmail: return "Gmail"
            case .calendar: return "Calendar"
            }
        }

        var sfSymbol: String {
            switch self {
            case .imessage: return "message.fill"
            case .gmail: return "envelope.fill"
            case .calendar: return "calendar"
            }
        }
    }
}
