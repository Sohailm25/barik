import Foundation

/// Provider for Aerospace window manager spaces integration
final class AerospaceSpacesProvider: SpacesProvider, SwitchableSpacesProvider, PollingBasedSpacesProvider {
    typealias SpaceType = AeroSpace
    
    /// Path to the aerospace executable
    let executablePath = ConfigManager.shared.config.aerospace.path
    
    /// Polling interval for Aerospace (in seconds)
    var pollingInterval: TimeInterval { 0.5 }

    /// Retrieves all spaces with their windows from Aerospace
    /// - Returns: Array of spaces with windows or nil if fetching failed
    func getSpacesWithWindows() -> [AeroSpace]? {
        guard var spaces = fetchSpaces(), let windows = fetchWindows() else {
            return nil
        }
        if let focusedSpace = fetchFocusedSpace() {
            for i in 0..<spaces.count {
                spaces[i].isFocused = (spaces[i].id == focusedSpace.id)
            }
        }
        let focusedWindow = fetchFocusedWindow()
        var spaceDict = Dictionary(
            uniqueKeysWithValues: spaces.map { ($0.id, $0) })
        for window in windows {
            var mutableWindow = window
            if let focused = focusedWindow, window.id == focused.id {
                mutableWindow.isFocused = true
            }
            if let ws = mutableWindow.workspace, !ws.isEmpty {
                if var space = spaceDict[ws] {
                    space.windows.append(mutableWindow)
                    spaceDict[ws] = space
                }
            } else if let focusedSpace = fetchFocusedSpace() {
                if var space = spaceDict[focusedSpace.id] {
                    space.windows.append(mutableWindow)
                    spaceDict[focusedSpace.id] = space
                }
            }
        }
        var resultSpaces = Array(spaceDict.values)
        for i in 0..<resultSpaces.count {
            resultSpaces[i].windows.sort { $0.id < $1.id }
        }
        return resultSpaces.filter { !$0.windows.isEmpty }
    }

    func focusSpace(spaceId: String, needWindowFocus: Bool) {
        _ = runAerospaceCommand(arguments: ["workspace", spaceId])
    }

    func focusWindow(windowId: String) {
        _ = runAerospaceCommand(arguments: ["focus", "--window-id", windowId])
    }

    private func runAerospaceCommand(arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        // Add error handling for standard error
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        // Use a semaphore to control synchronization
        let outputSemaphore = DispatchSemaphore(value: 0)
        var outputData: Data?
        var commandError: Error?
        
        // Set up asynchronous reading to avoid deadlocks
        let outputHandle = pipe.fileHandleForReading
        outputHandle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if data.count > 0 {
                if outputData == nil {
                    outputData = data
                } else {
                    outputData?.append(data)
                }
            } else {
                // EOF reached, signal completion
                outputHandle.readabilityHandler = nil
                outputSemaphore.signal()
            }
        }
        
        do {
            try process.run()
        } catch {
            print("Aerospace error: \(error)")
            return nil
        }
        
        // Wait for process with a reasonable timeout (2 seconds)
        let timeoutResult = DispatchTimeoutResult.success
        
        // If process takes too long, kill it
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
            if process.isRunning {
                process.terminate()
                if outputData == nil {
                    commandError = NSError(domain: "AerospaceProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Command timed out"])
                }
                outputSemaphore.signal()
            }
        }
        
        // Wait for output completion
        _ = outputSemaphore.wait(timeout: .now() + 2.0)
        
        // Cleanup
        outputHandle.readabilityHandler = nil
        
        if let error = commandError {
            print("Aerospace command error: \(error)")
            return nil
        }
        
        return outputData
    }

    private func fetchSpaces() -> [AeroSpace]? {
        guard
            let data = runAerospaceCommand(arguments: [
                "list-workspaces", "--all", "--json",
            ])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([AeroSpace].self, from: data)
        } catch {
            print("Decode spaces error: \(error)")
            return nil
        }
    }

    private func fetchWindows() -> [AeroWindow]? {
        guard
            let data = runAerospaceCommand(arguments: [
                "list-windows", "--all", "--json", "--format",
                "%{window-id} %{app-name} %{window-title} %{workspace}",
            ])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([AeroWindow].self, from: data)
        } catch {
            print("Decode windows error: \(error)")
            return nil
        }
    }

    private func fetchFocusedSpace() -> AeroSpace? {
        guard
            let data = runAerospaceCommand(arguments: [
                "list-workspaces", "--focused", "--json",
            ])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([AeroSpace].self, from: data).first
        } catch {
            print("Decode focused space error: \(error)")
            return nil
        }
    }

    private func fetchFocusedWindow() -> AeroWindow? {
        guard
            let data = runAerospaceCommand(arguments: [
                "list-windows", "--focused", "--json",
            ])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([AeroWindow].self, from: data).first
        } catch {
            print("Decode focused window error: \(error)")
            return nil
        }
    }
}
