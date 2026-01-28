// ABOUTME: Action items extracted from messages/calendar by LLM prioritization.
// ABOUTME: Used in DigestService to track user tasks with priority levels.

import Foundation

struct ActionItem: Identifiable, Codable, Equatable {
    let id: UUID
    let source: String
    let text: String
    let priority: Priority
    let timestamp: Date
    var isChecked: Bool

    init(
        id: UUID = UUID(),
        source: String,
        text: String,
        priority: Priority,
        timestamp: Date = Date(),
        isChecked: Bool = false
    ) {
        self.id = id
        self.source = source
        self.text = text
        self.priority = priority
        self.timestamp = timestamp
        self.isChecked = isChecked
    }

    enum Priority: String, Codable, Comparable, CaseIterable {
        case critical
        case important
        case normal
        case low

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            let order: [Priority] = [.low, .normal, .important, .critical]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
}
