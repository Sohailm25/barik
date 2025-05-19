import Foundation

/// Provider for Yabai window manager spaces integration
final class YabaiSpacesProvider: SpacesProvider, SwitchableSpacesProvider, PollingBasedSpacesProvider {
    typealias SpaceType = YabaiSpace
    
    /// Path to the yabai executable
    let executablePath = ConfigManager.shared.config.yabai.path
    
    /// Polling interval for Yabai (in seconds)
    var pollingInterval: TimeInterval { 0.05 }

    /// Runs a yabai command with the given arguments
    /// - Parameter arguments: Command arguments to pass to yabai
    /// - Returns: Output data from the command or nil if it failed
    private func runYabaiCommand(arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            print("Yabai error: \(error)")
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }

    private func fetchSpaces() -> [YabaiSpace]? {
        guard
            let data = runYabaiCommand(arguments: ["-m", "query", "--spaces"])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            let spaces = try decoder.decode([YabaiSpace].self, from: data)
            return spaces
        } catch {
            print("Decode yabai spaces error: \(error)")
            return nil
        }
    }

    private func fetchWindows() -> [YabaiWindow]? {
        guard
            let data = runYabaiCommand(arguments: ["-m", "query", "--windows"])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            let windows = try decoder.decode([YabaiWindow].self, from: data)
            return windows
        } catch {
            print("Decode yabai windows error: \(error)")
            return nil
        }
    }

    func getSpacesWithWindows() -> [YabaiSpace]? {
        guard let spaces = fetchSpaces(), let windows = fetchWindows() else {
            return nil
        }
        // Filter out hidden/floating/sticky windows by default
        let filteredWindows = windows.filter {
            !($0.isHidden || $0.isFloating || $0.isSticky)
        }
        
        // Create a dictionary to associate windows with their spaces
        var spaceDict = Dictionary(
            uniqueKeysWithValues: spaces.map { ($0.id, $0) })
        
        // Process windows and add them to appropriate spaces
        for window in filteredWindows {
            let spaceIdStr = String(window.spaceId)
            if var space = spaceDict[spaceIdStr] {
                space.windows.append(window)
                spaceDict[spaceIdStr] = space
            }
        }
        
        // Create final array of spaces and sort windows
        var resultSpaces = Array(spaceDict.values)
        for i in 0..<resultSpaces.count {
            // Sort windows by stack index
            resultSpaces[i].windows.sort { $0.stackIndex < $1.stackIndex }
        }
        return resultSpaces.filter { !$0.windows.isEmpty }
    }

    func focusSpace(spaceId: String, needWindowFocus: Bool) {
        _ = runYabaiCommand(arguments: ["-m", "space", "--focus", spaceId])
        if !needWindowFocus { return }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + 0.1
        ) {
            if let spaces = self.getSpacesWithWindows() {
                if let space = spaces.first(where: { $0.id == spaceId }) {
                    let hasFocused = space.windows.contains { $0.isFocused }
                    if !hasFocused, let firstWindow = space.windows.first {
                        _ = self.runYabaiCommand(arguments: [
                            "-m", "window", "--focus", firstWindow.id,
                        ])
                    }
                }
            }
        }
    }

    func focusWindow(windowId: String) {
        _ = runYabaiCommand(arguments: ["-m", "window", "--focus", windowId])
    }
}
