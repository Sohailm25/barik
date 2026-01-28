// ABOUTME: Persists workspace display name overrides as JSON at ~/.config/barik/workspace-names.json.
// ABOUTME: Provides get/set/remove for workspace ID → display name mappings with atomic file writes.

import Foundation
import Combine

final class WorkspaceNameService: ObservableObject {
    static let shared = WorkspaceNameService()

    @Published private(set) var names: [String: String] = [:]

    private let filePath: String

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.filePath = "\(home)/.config/barik/workspace-names.json"
        load()
    }

    init(filePath: String) {
        self.filePath = filePath
        load()
    }

    func getDisplayName(for workspaceId: String) -> String? {
        return names[workspaceId]
    }

    func setDisplayName(_ name: String, for workspaceId: String) {
        names[workspaceId] = name
        save()
    }

    func removeDisplayName(for workspaceId: String) {
        names.removeValue(forKey: workspaceId)
        save()
    }

    func allDisplayNames() -> [String: String] {
        return names
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: filePath) else { return }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            names = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            names = [:]
        }
    }

    private func save() {
        let dir = (filePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        do {
            let data = try JSONEncoder().encode(names)
            let tempPath = filePath + ".tmp"
            try data.write(to: URL(fileURLWithPath: tempPath))
            try FileManager.default.moveItem(atPath: tempPath, toPath: filePath)
        } catch {
            try? FileManager.default.removeItem(atPath: filePath)
            do {
                let data = try JSONEncoder().encode(names)
                try data.write(to: URL(fileURLWithPath: filePath))
            } catch {
                print("WorkspaceNameService: failed to save: \(error)")
            }
        }
    }
}
