import Foundation
import SwiftUI

enum WidgetType: String, CaseIterable, Codable {
    case settings, network, battery, time
}

struct WidgetItem: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    let type: WidgetType
}
