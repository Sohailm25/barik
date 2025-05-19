import AppKit

struct AeroWindow: WindowModel {
    let id: String
    let title: String?
    let appName: String?
    var isFocused: Bool
    let appBundleIdentifier: String?
    let workspace: String?

    enum CodingKeys: String, CodingKey {
        case id = "window-id"
        case title = "window-title"
        case appName = "app-name"
        case workspace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let intId = try container.decode(Int.self, forKey: .id)
        id = String(intId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
        isFocused = false
        appBundleIdentifier = nil // Aerospace doesn't provide bundle identifiers directly
    }
    
    init(id: String, title: String?, appName: String?, workspace: String?, isFocused: Bool = false) {
        self.id = id
        self.title = title
        self.appName = appName
        self.workspace = workspace
        self.isFocused = isFocused
        self.appBundleIdentifier = nil
    }
}

struct AeroSpace: SpaceModel {
    typealias WindowType = AeroWindow
    let workspace: String
    var id: String { workspace }
    var isFocused: Bool
    var windows: [AeroWindow]

    enum CodingKeys: String, CodingKey {
        case workspace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspace = try container.decode(String.self, forKey: .workspace)
        isFocused = false
        windows = []
    }

    init(workspace: String, isFocused: Bool = false, windows: [AeroWindow] = []) {
        self.workspace = workspace
        self.isFocused = isFocused
        self.windows = windows
    }
}
