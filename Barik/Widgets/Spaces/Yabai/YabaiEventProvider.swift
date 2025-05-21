import Foundation
import Combine
import Darwin

// Define UNIX_PATH_MAX which isn't exposed by Darwin
private let UNIX_PATH_MAX = 104

/// Provider for Yabai window manager spaces integration with event-based updates
final class YabaiEventSpacesProvider: SpacesProvider, SwitchableSpacesProvider, EventBasedSpacesProvider {
    typealias SpaceType = YabaiSpace
    
    /// Path to the yabai executable
    let executablePath = ConfigManager.shared.config.yabai.path
    
    /// Socket path for receiving Yabai events
    private let socketPath = "/tmp/yabai_events.sock"
    
    /// Publisher for space events
    private let eventSubject = PassthroughSubject<SpaceEvent, Never>()
    
    /// Publisher for space events (accessible to subscribers)
    var spacesPublisher: AnyPublisher<SpaceEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// File descriptor for the Unix socket
    private var socketFileDescriptor: Int32 = -1
    
    /// Dispatch source for monitoring socket activity
    private var socketSource: DispatchSourceRead?
    
    /// Queue for socket operations
    private let queue = DispatchQueue(label: "com.barik.yabai.events")
    
    /// Timer for periodic refreshes
    private var refreshTimer: Timer?
    
    /// Interval for periodic state refresh in seconds
    private let refreshInterval: TimeInterval
    
    /// Whether to use event-based provider
    private let useEventBasedProvider: Bool
    
    /// Initialize the provider with default settings
    init(refreshInterval: TimeInterval = 10.0) {
        self.refreshInterval = refreshInterval
        self.useEventBasedProvider = ConfigManager.shared.config.experimental.eventBasedYabaiProvider
    }
    
    // MARK: - Command Execution
    
    /// Runs a yabai command with the given arguments synchronously on the current thread
    /// - Parameters:
    ///   - arguments: Command arguments to pass to yabai
    ///   - timeout: Timeout in seconds (default: 3.0)
    /// - Returns: Output data from the command or nil if it failed
    private func runYabaiCommand(arguments: [String], timeout: TimeInterval = 3.0) -> Data? {
        // Don't run commands if the path is empty
        guard !executablePath.isEmpty else {
            print("Yabai path is empty")
            return nil
        }
        
        // Check if file exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: executablePath) {
            print("Yabai executable not found at path: \(executablePath)")
            return nil
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            
            // Set up a timer to kill the process if it takes too long
            var timedOut = false
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    process.terminate()
                    timedOut = true
                    print("Yabai command timed out after \(timeout) seconds")
                }
            }
            
            // Wait for the process to complete
            process.waitUntilExit()
            
            // Check if we timed out
            if timedOut {
                return nil
            }
            
            // Check for error output
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if !errorData.isEmpty, let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                print("Yabai command error: \(errorString)")
            }
            
            // Check for normal termination
            if process.terminationStatus != 0 {
                print("Yabai command failed with status: \(process.terminationStatus)")
                return nil
            }
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return outputData
        } catch {
            print("Failed to run yabai command: \(error)")
            return nil
        }
    }
    
    /// Run a shell command to send data to our Unix socket
    private func runShellCommand(_ command: String, timeout: TimeInterval = 3.0) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
        do {
            try process.run()
            
            // Set up a timer to kill the process if it takes too long
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    process.terminate()
                    print("Shell command timed out after \(timeout) seconds")
                }
            }
            
            // Let it run and exit on its own - we don't need the output
        } catch {
            print("Failed to run shell command: \(error)")
        }
    }
    
    // MARK: - Space and Window Retrieval
    
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
    
    // MARK: - Event Handling
    
    /// Start observing Yabai events
    func startObserving() {
        // Run in a background queue to avoid blocking the main thread
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // First clean up any existing setup
            self.cleanupUnixSocket()
            
            // Setup the socket with a retry mechanism
            var setupSuccessful = self.setupUnixSocket()
            
            // Retry socket setup a few times if it fails
            if !setupSuccessful {
                for i in 1...3 {
                    print("Retrying Unix socket setup (attempt \(i)/3)...")
                    // Short delay before retry
                    Thread.sleep(forTimeInterval: 0.5)
                    setupSuccessful = self.setupUnixSocket()
                    if setupSuccessful { break }
                }
            }
            
            if setupSuccessful {
                self.registerYabaiSignals()
                
                // Start periodic refreshes as a backup for missed events
                self.startPeriodicRefresh(interval: self.refreshInterval)
                
                // Emit initial state on the main queue
                if let spaces = self.getSpacesWithWindows() {
                    let anySpaces = spaces.map { AnySpace($0) }
                    DispatchQueue.main.async {
                        self.eventSubject.send(.initialState(anySpaces))
                    }
                }
            } else {
                print("Failed to setup Unix socket after multiple attempts. Event-based updates will not work.")
            }
        }
    }
    
    /// Stop observing Yabai events
    func stopObserving() {
        queue.async { [weak self] in
            self?.stopPeriodicRefresh()
            self?.cleanupUnixSocket()
        }
    }
    
    /// Perform cleanup when instance is deallocated
    deinit {
        stopPeriodicRefresh()
        cleanupUnixSocket()
        print("YabaiSpacesProvider deallocated")
    }
    
    // MARK: - Socket Handling
    
    /// Setup the Unix socket for receiving events
    @discardableResult
    private func setupUnixSocket() -> Bool {
        print("Setting up Unix socket at \(socketPath)...")
        
        // Remove existing socket file if it exists
        if FileManager.default.fileExists(atPath: socketPath) {
            do {
                try FileManager.default.removeItem(atPath: socketPath)
                print("Removed existing socket file")
            } catch {
                print("Error removing existing socket file: \(error)")
                return false
            }
        }
        
        // Create socket
        socketFileDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 {
            print("Failed to create socket: \(String(cString: strerror(errno)))")
            return false
        }
        
        // Set socket options
        var on: Int32 = 1
        if setsockopt(socketFileDescriptor, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size)) == -1 {
            print("Failed to set socket options: \(String(cString: strerror(errno)))")
            close(socketFileDescriptor)
            socketFileDescriptor = -1
            return false
        }
        
        // Prepare the Unix socket address
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathCount = min(socketPath.utf8.count, Int(UNIX_PATH_MAX - 1))
        _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            socketPath.withCString {
                strncpy(ptr, $0, pathCount)
            }
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        
        // Bind the socket
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { addrPtr in
                bind(socketFileDescriptor, addrPtr, addrLen)
            }
        }
        
        if bindResult == -1 {
            print("Failed to bind socket: \(String(cString: strerror(errno)))")
            close(socketFileDescriptor)
            socketFileDescriptor = -1
            return false
        }
        
        // Make sure socket permissions allow yabai to connect
        let result = chmod(socketPath, 0o666)
        if result == -1 {
            print("Failed to set socket permissions: \(String(cString: strerror(errno)))")
            // We continue anyway as this might still work in some cases
        }
        
        // Start listening for connections
        if listen(socketFileDescriptor, 10) == -1 {
            print("Failed to listen on socket: \(String(cString: strerror(errno)))")
            close(socketFileDescriptor)
            socketFileDescriptor = -1
            return false
        }
        
        // Create a dispatch source to monitor for connections
        socketSource = DispatchSource.makeReadSource(fileDescriptor: socketFileDescriptor, queue: queue)
        socketSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // Accept the connection
            var addr = sockaddr()
            var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
            let connectionFd = withUnsafeMutablePointer(to: &addr) { addrPtr in
                withUnsafeMutablePointer(to: &addrLen) { lenPtr in
                    accept(self.socketFileDescriptor, addrPtr, lenPtr)
                }
            }
            
            if connectionFd == -1 {
                print("Failed to accept connection: \(String(cString: strerror(errno)))")
                return
            }
            
            // Read data from the connection
            self.readDataFromConnection(connectionFd)
        }
        
        socketSource?.setCancelHandler {
            close(self.socketFileDescriptor)
            self.socketFileDescriptor = -1
            try? FileManager.default.removeItem(atPath: self.socketPath)
        }
        
        socketSource?.resume()
        print("Yabai event socket ready at \(socketPath)")
        return true
    }
    
    /// Read data from a connection
    private func readDataFromConnection(_ connectionFd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(connectionFd, &buffer, buffer.count)
        
        defer {
            close(connectionFd)
        }
        
        if bytesRead == -1 {
            print("Failed to read from socket: \(String(cString: strerror(errno)))")
            return
        }
        
        if bytesRead > 0 {
            let data = Data(bytes: buffer, count: bytesRead)
            
            // Process data in the background to avoid blocking socket handling
            DispatchQueue.global().async { [weak self] in
                self?.processReceivedData(data)
            }
        }
    }
    
    /// Register signals with Yabai
    private func registerYabaiSignals() {
        // Remove any existing signals
        removeYabaiSignals()
        
        // Events to monitor
        let events = [
            "space_changed",
            "window_created",
            "window_destroyed",
            "window_focused",
            "window_title_changed",
            "space_created",
            "space_destroyed"
        ]
        
        // Create a unique identifier for this session
        let sessionId = UUID().uuidString.prefix(8)
        
        for event in events {
            let label = "barik_\(sessionId)_\(event)"
            
            // Create the absolute simplest command that just notifies our socket
            // with the event name - no complex JSON formatting, no variables
            let bashCommand: String
            if event == "space_changed" {
                bashCommand = """
                printf '%s:%s' "\(event)" "$YABAI_SPACE_ID" | nc -U -w1 \(socketPath)
                """
            } else {
                bashCommand = """
                printf '%s' "\(event)" | nc -U -w1 \(socketPath)
                """
            }
            
            // Register the signal with yabai
            _ = runYabaiCommand(arguments: [
                "-m", "signal", "--add",
                "event=\(event)",
                "label=\(label)",
                "action=bash -c '\(bashCommand)'"
            ])
            
            print("Registered Yabai signal for \(event)")
        }
    }
    
    /// Remove registered Yabai signals
    private func removeYabaiSignals() {
        guard let data = runYabaiCommand(arguments: ["-m", "signal", "--list"]),
              let output = String(data: data, encoding: .utf8) else {
            return
        }
        
        for line in output.split(separator: "\n") {
            if line.contains("barik_") {
                if let labelRange = line.range(of: "label=") {
                    let startIndex = labelRange.upperBound
                    if let endIndex = line[startIndex...].firstIndex(where: { $0.isWhitespace }) {
                        let label = String(line[startIndex..<endIndex])
                        _ = runYabaiCommand(arguments: ["-m", "signal", "--remove", label])
                        print("Removed Yabai signal: \(label)")
                    } else {
                        // In case there is no whitespace after the label (end of line)
                        let label = String(line[startIndex...])
                        _ = runYabaiCommand(arguments: ["-m", "signal", "--remove", label])
                        print("Removed Yabai signal: \(label)")
                    }
                }
            }
        }
    }
    
    /// Process data received from the socket
    private func processReceivedData(_ data: Data) {
        guard let eventString = String(data: data, encoding: .utf8) else {
            print("Failed to decode socket data")
            return
        }
        
        // Debugging output
        print("Received Yabai event string: \(eventString)")
        
        // Clean up the event string
        let trimmedString = eventString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var eventName = trimmedString
        var eventArg: String? = nil

        if let colonIndex = trimmedString.firstIndex(of: ":") {
            eventName = String(trimmedString[..<colonIndex])
            let argStartIndex = trimmedString.index(after: colonIndex)
            if argStartIndex < trimmedString.endIndex {
                eventArg = String(trimmedString[argStartIndex...])
            }
        }
        
        // A valid event is either a plain event name or contains one of our event names
        let validEventNames = [
            "space_changed",
            "window_created", 
            "window_destroyed",
            "window_focused",
            "window_title_changed",
            "space_created",
            "space_destroyed"
        ]
        
        // Find which event we received based on the parsed eventName
        let detectedEventType = validEventNames.first { eventName == $0 }
        
        if let confirmedEventType = detectedEventType {
            print("Processing Yabai event: \(confirmedEventType) (Arg: \(eventArg ?? "nil"))")

            // Send immediate event if it's space_changed with an ID and advanced handling is enabled
            if confirmedEventType == "space_changed", let spaceId = eventArg, !spaceId.isEmpty, useEventBasedProvider {
                DispatchQueue.main.async { [weak self] in
                    self?.eventSubject.send(.focusChanged(spaceId))
                    print("Sent immediate focusChanged for space ID: \(spaceId) from event argument.")
                }
            }
            
            // Proceed with full data fetch and processing
            queue.async { [weak self] in
                guard let self = self else { return }
                
                // Fetch current spaces and windows data
                guard let spaces = self.fetchSpaces(),
                      let windows = self.fetchWindows() else {
                    print("Failed to fetch current state after \(confirmedEventType) event")
                    return
                }
                
                // Process the update on the main thread
                DispatchQueue.main.async {
                    self.processEventWithFetchedData(eventType: confirmedEventType, spaces: spaces, windows: windows)
                }
            }
        } else {
            print("Unrecognized event name: \(eventName) (from: \(trimmedString)), ignoring")
        }
    }
    
    /// Process an event with freshly fetched data
    private func processEventWithFetchedData(eventType: String, spaces: [YabaiSpace], windows: [YabaiWindow]) {
        // Filter out hidden/floating/sticky windows
        let filteredWindows = windows.filter {
            !($0.isHidden || $0.isFloating || $0.isSticky)
        }
        
        // Create dictionary of spaces
        var spaceDict = Dictionary(
            uniqueKeysWithValues: spaces.map { ($0.id, $0) })
        
        // Assign windows to spaces
        for window in filteredWindows {
            let spaceIdStr = String(window.spaceId)
            if var space = spaceDict[spaceIdStr] {
                space.windows.append(window)
                spaceDict[spaceIdStr] = space
            }
        }
        
        // Create final spaces array with sorted windows
        var resultSpaces = Array(spaceDict.values)
        for i in 0..<resultSpaces.count {
            resultSpaces[i].windows.sort { $0.stackIndex < $1.stackIndex }
        }
        
        // Event-specific processing
        switch eventType {
        case "space_changed":
            if useEventBasedProvider {
                // Event-based provider keeps track of focus separately in SpacesViewModel
                // The .focusChanged event with the space ID from the argument was already sent immediately.
                // Here, we just need to send the updated windows for that space based on fresh data.
                if let focusedSpaceFromFetch = spaces.first(where: { $0.isFocused }) {
                    let focusedSpaceIdStr = String(focusedSpaceFromFetch.id)
                    
                    // Verify if the initially reported focused space ID matches the one from fetch.
                    // This is mostly for robustness, the immediate .focusChanged should handle the space focus change.
                    // If they differ significantly, it might indicate rapid changes, and initialState could be safer.
                    // However, for now, we trust the fetch result for window data primarily.

                    let windowsInFocusedSpace = filteredWindows.filter { String($0.spaceId) == focusedSpaceIdStr }
                                                              .sorted { $0.stackIndex < $1.stackIndex }
                    let anyWindowsInFocusedSpace = windowsInFocusedSpace.map { AnyWindow($0) }
                    self.eventSubject.send(.windowsUpdated(focusedSpaceIdStr, anyWindowsInFocusedSpace))
                    print("Sent .windowsUpdated for space \(focusedSpaceIdStr) after full fetch for space_changed event.")
                } else {
                    // If no space is focused after fetch (unlikely for space_changed), send full update as fallback.
                    print("No focused space found after fetch for space_changed event. Sending .initialState.")
                    let filteredResultSpaces = resultSpaces.filter { !$0.windows.isEmpty }
                    let anySpaces = filteredResultSpaces.map { AnySpace($0) }
                    self.eventSubject.send(.initialState(anySpaces))
                }
            } else {
                // Simple handling: send a full state update for space changes
                let filteredResultSpaces = resultSpaces.filter { !$0.windows.isEmpty }
                let anySpaces = filteredResultSpaces.map { AnySpace($0) }
                self.eventSubject.send(.initialState(anySpaces))
            }
            
        case "window_created", "window_destroyed", "window_focused", "window_title_changed":
            if useEventBasedProvider {
                // Event-based handling for window events
                // If a window event occurs, it implies a space is focused (usually the one containing the window).
                // We need to update the windows of that focused space.
                if let focusedSpace = spaces.first(where: { $0.isFocused }) {
                    let focusedSpaceIdStr = String(focusedSpace.id)
                    var spaceWindows = filteredWindows.filter { String($0.spaceId) == focusedSpaceIdStr }
                    spaceWindows.sort { $0.stackIndex < $1.stackIndex }
                    let anyWindows = spaceWindows.map { AnyWindow($0) }
                    self.eventSubject.send(.windowsUpdated(focusedSpaceIdStr, anyWindows))
                } else {
                     print("Warning: Window event ('\(eventType)') processed, but no focused space found in fetched data. Window updates might be incomplete.")
                     // As a fallback, send full state, as window changes might affect unfocused spaces too in some edge cases,
                     // or the focused space detection failed.
                    let filteredResultSpaces = resultSpaces.filter { !$0.windows.isEmpty }
                    let anySpaces = filteredResultSpaces.map { AnySpace($0) }
                    self.eventSubject.send(.initialState(anySpaces))
                }
            } else {
                // Simple handling: send full state for window events
                let filteredResultSpaces = resultSpaces.filter { !$0.windows.isEmpty }
                let anySpaces = filteredResultSpaces.map { AnySpace($0) }
                self.eventSubject.send(.initialState(anySpaces))
            }
            
        case "space_created", "space_destroyed":
            // For these events, send a complete state update regardless of mode
            let filteredSpaces = resultSpaces.filter { !$0.windows.isEmpty }
            let anySpaces = filteredSpaces.map { AnySpace($0) }
            self.eventSubject.send(.initialState(anySpaces))
            
        default:
            // For any other event, also send a complete state update
            let filteredSpaces = resultSpaces.filter { !$0.windows.isEmpty }
            let anySpaces = filteredSpaces.map { AnySpace($0) }
            self.eventSubject.send(.initialState(anySpaces))
        }
    }
    
    /// Clean up the Unix socket
    private func cleanupUnixSocket() {
        // Clean up signals first
        removeYabaiSignals()
        
        // Clean up socket
        socketSource?.cancel()
        socketSource = nil
        
        if socketFileDescriptor != -1 {
            close(socketFileDescriptor)
            socketFileDescriptor = -1
        }
        
        // Remove the socket file
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    /// Manually refresh the spaces and windows data
    func refreshState() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            print("Manually refreshing Yabai spaces state...")
            if let spaces = self.getSpacesWithWindows() {
                let anySpaces = spaces.map { AnySpace($0) }
                DispatchQueue.main.async {
                    self.eventSubject.send(.initialState(anySpaces))
                }
            } else {
                print("Failed to refresh Yabai spaces state")
            }
        }
    }
    
    /// Schedule periodic state refreshes to ensure UI remains up-to-date
    /// even if some events are missed
    func startPeriodicRefresh(interval: TimeInterval = 10.0) {
        // Cancel any existing timer
        stopPeriodicRefresh()
        
        // Create a new timer that refreshes state every N seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }
    
    /// Stop periodic refreshes
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - YabaiWindow Extension

extension YabaiWindow {
    // Add a convenience initializer for creating from dictionary
    init(id: String, title: String?, appName: String?, isFocused: Bool, appBundleIdentifier: String?, stackIndex: Int, isHidden: Bool, isFloating: Bool, isSticky: Bool, spaceId: Int) {
        self.id = id
        self.title = title
        self.appName = appName
        self.isFocused = isFocused
        self.appBundleIdentifier = appBundleIdentifier
        self.stackIndex = stackIndex
        self.isHidden = isHidden
        self.isFloating = isFloating
        self.isSticky = isSticky
        self.spaceId = spaceId
    }
}
