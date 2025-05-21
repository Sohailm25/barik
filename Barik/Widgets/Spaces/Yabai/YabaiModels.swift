import AppKit

struct YabaiWindow: WindowModel, Equatable {
    let id: String
    let title: String?
    let appName: String?
    var isFocused: Bool
    let appBundleIdentifier: String?
    let stackIndex: Int
    let isHidden: Bool
    let isFloating: Bool
    let isSticky: Bool
    let spaceId: Int

    enum CodingKeys: String, CodingKey {
        case id
        case spaceId = "space"
        case title
        case appName = "app"
        case isFocused = "has-focus"
        case stackIndex = "stack-index"
        case isHidden = "is-hidden"
        case isFloating = "is-floating"
        case isSticky = "is-sticky"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let intId = try container.decode(Int.self, forKey: .id)
        id = String(intId)
        spaceId = try container.decode(Int.self, forKey: .spaceId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        isFocused = try container.decode(Bool.self, forKey: .isFocused)
        stackIndex = try container.decodeIfPresent(Int.self, forKey: .stackIndex) ?? 0
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        isFloating = try container.decode(Bool.self, forKey: .isFloating)
        isSticky = try container.decode(Bool.self, forKey: .isSticky)
        appBundleIdentifier = nil // Yabai doesn't provide bundle identifiers directly
    }
    
    static func == (lhs: YabaiWindow, rhs: YabaiWindow) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.appName == rhs.appName &&
               lhs.isFocused == rhs.isFocused &&
               lhs.stackIndex == rhs.stackIndex &&
               lhs.isHidden == rhs.isHidden &&
               lhs.isFloating == rhs.isFloating &&
               lhs.isSticky == rhs.isSticky &&
               lhs.spaceId == rhs.spaceId
    }
}

struct YabaiSpace: SpaceModel, Equatable {
    typealias WindowType = YabaiWindow
    
    var id: String { String(index) }
    let index: Int
    var isFocused: Bool
    var windows: [YabaiWindow] = []

    enum CodingKeys: String, CodingKey {
        case index
        case isFocused = "has-focus"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        isFocused = try container.decode(Bool.self, forKey: .isFocused)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(isFocused, forKey: .isFocused)
    }
    
    static func == (lhs: YabaiSpace, rhs: YabaiSpace) -> Bool {
        return lhs.id == rhs.id &&
               lhs.isFocused == rhs.isFocused &&
               lhs.windows == rhs.windows
    }
}
