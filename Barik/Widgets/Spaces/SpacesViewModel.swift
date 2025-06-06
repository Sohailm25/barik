import AppKit
import Combine
import Foundation

/// ViewModel for managing and displaying spaces
final class SpacesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var spaces: [AnySpace] = []
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var provider: AnySpacesProvider?
    private var cancellables: Set<AnyCancellable> = []
    private var spacesById: [String: AnySpace] = [:]
    private var focusedSpaceId: String?
    private var focusedWindowId: String?
    
    /// Whether to use event-based Yabai provider
    private let useEventBasedProvider: Bool
    
    // MARK: - Initialization
    
    init() {
        self.useEventBasedProvider = ConfigManager.shared.config.experimental.eventBasedYabaiProvider
        
        let runningApps = NSWorkspace.shared.runningApplications.compactMap {
            $0.bundleIdentifier
        }
        
        if runningApps.contains("com.dexterleng.aerospaces") {
            setupAerospaceProvider()
        } else if ConfigManager.shared.config.yabai.path != "" {
            setupYabaiProvider()
        }
    }
    
    // MARK: - Provider Setup
    
    private func setupAerospaceProvider() {
        provider = AnySpacesProvider(AerospaceSpacesProvider())
        startMonitoring()
    }
    
    private func setupYabaiProvider() {
        if ConfigManager.shared.config.experimental.eventBasedYabaiProvider {
            provider = AnySpacesProvider(YabaiEventSpacesProvider())
            startMonitoring()
        } else {
            provider = AnySpacesProvider(YabaiSpacesProvider())
            startMonitoring()
        }
    }
    
    // MARK: - Monitoring Management
    
    /// Starts monitoring spaces based on the provider type
    private func startMonitoring() {
        if let provider = provider {
            if provider.isEventBased {
                startMonitoringEventBasedProvider()
            } else if provider.isPollingBased {
                startMonitoringPollingBasedProvider()
            }
        }
    }
    
    /// Stops monitoring spaces based on the provider type
    private func stopMonitoring() {
        if let provider = provider {
            if provider.isEventBased {
                stopMonitoringEventBasedProvider()
            } else if provider.isPollingBased {
                stopMonitoringPollingBasedProvider()
            }
        }
    }
    
    // MARK: - Polling-Based Monitoring
    
    /// Starts polling-based monitoring
    private func startMonitoringPollingBasedProvider() {
        guard let provider = provider else { return }
        
        let interval = provider.pollingInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.loadSpaces()
        }
        loadSpaces()
    }
    
    /// Stops polling-based monitoring
    private func stopMonitoringPollingBasedProvider() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Event-Based Monitoring
    
    /// Starts event-based monitoring
    private func startMonitoringEventBasedProvider() {
        guard let provider = provider else { return }
        
        provider.spacesPublisher?
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleSpaceEvent(event)
            }
            .store(in: &cancellables)
        
        provider.startObserving()
    }
    
    /// Stops event-based monitoring
    private func stopMonitoringEventBasedProvider() {
        provider?.stopObserving()
        cancellables.removeAll()
    }
    
    // MARK: - Event Handling
    
    /// Handle a space event
    /// - Parameter event: The space event to handle
    private func handleSpaceEvent(_ event: SpaceEvent) {
        if useEventBasedProvider {
            handleSpaceEventWithEventProvider(event)
        } else {
            handleSpaceEventSimple(event)
        }
    }
    
    /// Handle a space event using the original simple approach
    /// - Parameter event: The space event to handle
    private func handleSpaceEventSimple(_ event: SpaceEvent) {
        switch event {
        case .initialState(let spaces):
            spacesById = Dictionary(uniqueKeysWithValues: spaces.map { ($0.id, $0) })
            updatePublishedSpaces()
            
        case .focusChanged(let spaceId):
            for (id, space) in spacesById {
                let newFocused = id == spaceId
                if space.isFocused != newFocused {
                    spacesById[id] = AnySpace(
                        id: space.id,
                        isFocused: newFocused,
                        windows: space.windows
                    )
                }
            }
            updatePublishedSpaces()
            
        case .windowsUpdated(let spaceId, let windows):
            if let space = spacesById[spaceId] {
                spacesById[spaceId] = AnySpace(
                    id: space.id,
                    isFocused: space.isFocused,
                    windows: windows
                )
            }
            updatePublishedSpaces()
        }
    }
    
    /// Handle a space event using the event-based approach
    /// - Parameter event: The space event to handle
    private func handleSpaceEventWithEventProvider(_ event: SpaceEvent) {
        switch event {
        case .initialState(let initialSpaces):
            // Determine initial focus
            self.focusedSpaceId = nil
            self.focusedWindowId = nil

            for space in initialSpaces {
                if space.isFocused {
                    self.focusedSpaceId = space.id
                    self.focusedWindowId = nil // Space focus overrides window focus if both are somehow true initially
                }
                // Check windows only if a space focus hasn't already been definitively set
                if self.focusedWindowId == nil { // Ensures that if space.isFocused was true, we don't immediately override focusedSpaceId by a window
                    for window in space.windows {
                        if window.isFocused {
                            self.focusedWindowId = window.id
                            self.focusedSpaceId = space.id // Window focus implies space focus
                            break // Only one window can be focused
                        }
                    }
                }
                if self.focusedWindowId != nil {
                    // If a window took focus, ensure no other space claims to be focusedSpaceId unless it's this window's space
                    if self.focusedSpaceId != space.id && space.isFocused {
                         // This case should ideally not happen if data is clean, but corrects it.
                         // Another space was marked focused, but a window in *this* space took focus.
                         // So, the focusedSpaceId is already correctly set to this window's space.
                    }
                    break // Found focused window, its space is now the focusedSpaceId
                }
            }

            // Apply the determined single focus
            var tempSpacesById: [String: AnySpace] = [:]
            for spaceEntry in initialSpaces { // No need for var spaceEntry
                let isThisSpaceFocused = (spaceEntry.id == self.focusedSpaceId)
                let updatedWindows = spaceEntry.windows.map { window -> AnyWindow in
                    var mutableWindow = window
                    // A window is focused only if it's the focusedWindowId AND its space is the focusedSpaceId
                    mutableWindow.isFocused = (window.id == self.focusedWindowId && isThisSpaceFocused)
                    return mutableWindow
                }
                // A space is focused if it's the focusedSpaceId (regardless of whether a specific window in it is focused)
                tempSpacesById[spaceEntry.id] = AnySpace(id: spaceEntry.id, isFocused: isThisSpaceFocused, windows: updatedWindows)
            }
            self.spacesById = tempSpacesById
            updatePublishedSpaces()

        case .focusChanged(let newFocusedSpaceId):
            self.focusedSpaceId = newFocusedSpaceId
            self.focusedWindowId = nil // Focus on space clears window focus

            var changed = false
            for (id, var space) in spacesById {
                let shouldBeFocused = (id == self.focusedSpaceId)
                var windowsChanged = false
                var updatedWindows = space.windows

                for i in 0..<updatedWindows.count {
                    if updatedWindows[i].isFocused {
                        updatedWindows[i].isFocused = false
                        windowsChanged = true
                    }
                }

                if space.isFocused != shouldBeFocused || windowsChanged {
                    spacesById[id] = AnySpace(id: space.id, isFocused: shouldBeFocused, windows: updatedWindows)
                    changed = true
                }
            }

            if changed {
                updatePublishedSpaces()
            }

        case .windowsUpdated(let updatedSpaceId, let incomingWindows):
            // Check if any incoming window claims focus
            var incomingWindowTakingFocus: String? = nil
            for window in incomingWindows {
                if window.isFocused {
                    incomingWindowTakingFocus = window.id
                    break
                }
            }

            if let windowId = incomingWindowTakingFocus {
                self.focusedWindowId = windowId
                self.focusedSpaceId = updatedSpaceId // Window focus dictates space focus
            } else {
                // No incoming window is focused. 
                // If the currently focused window was in this updatedSpaceId, it's no longer focused.
                if self.focusedSpaceId == updatedSpaceId && self.focusedWindowId != nil {
                    // Check if focusedWindowId was part of incomingWindows, if not, it means it disappeared
                    // or if it was part of incomingWindows but no longer focused (handled by incomingWindowTakingFocus being nil)
                    let focusedWindowStillExistsAndFocused = incomingWindows.contains(where: { $0.id == self.focusedWindowId && $0.isFocused })
                    if !focusedWindowStillExistsAndFocused {
                        self.focusedWindowId = nil
                        // The space itself (updatedSpaceId) might still be the focused one, if no other window/space takes precedence.
                        // The focusedSpaceId remains updatedSpaceId unless another event changes it.
                    }
                }
                // If focusedWindowId is now nil, and focusedSpaceId was this space, then this space remains the focused entity.
            }
            
            var changed = false
            for (id, var existingSpace) in spacesById {
                let isThisSpaceTheGloballyFocusedSpace = (id == self.focusedSpaceId)
                var finalWindows: [AnyWindow]

                if id == updatedSpaceId {
                    finalWindows = incomingWindows.map { window -> AnyWindow in
                        var mutableWindow = window
                        mutableWindow.isFocused = (window.id == self.focusedWindowId && isThisSpaceTheGloballyFocusedSpace)
                        return mutableWindow
                    }
                } else {
                    finalWindows = existingSpace.windows.map { window -> AnyWindow in
                        var mutableWindow = window
                        // Unfocus windows in other spaces if a specific window is focused, or if this space is not the globally focused one
                        mutableWindow.isFocused = false // Simplified: only focusedWindowId in focusedSpaceId can be true
                        return mutableWindow
                    }
                }
                
                if existingSpace.isFocused != isThisSpaceTheGloballyFocusedSpace || existingSpace.windows != finalWindows {
                    spacesById[id] = AnySpace(id: existingSpace.id, isFocused: isThisSpaceTheGloballyFocusedSpace, windows: finalWindows)
                    changed = true
                }
            }

            if changed {
                updatePublishedSpaces()
            }
        }
    }
    
    /// Updates the published spaces collection
    private func updatePublishedSpaces() {
        let sortedSpaces = spacesById.values.sorted { $0.id < $1.id }
        if sortedSpaces != spaces {
            spaces = sortedSpaces
        }
    }
    
    // MARK: - Space Loading
    
    /// Loads spaces from the provider
    private func loadSpaces() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let provider = self.provider else { return }
            
            guard let spaces = provider.getSpacesWithWindows() else { return }
            
            // Sort spaces by ID
            let sortedSpaces = spaces.sorted { space1, space2 in
                let id1 = space1.id
                let id2 = space2.id
                
                // Try to convert IDs to integers for numerical sorting
                if let int1 = Int(id1), let int2 = Int(id2) {
                    return int1 < int2
                }
                
                // If one ID is a number and the other isn't, put numbers first
                if Int(id1) != nil {
                    return true
                }
                if Int(id2) != nil {
                    return false
                }
                
                // Both IDs contain non-numeric characters, use string sorting
                return id1 < id2
            }
            
            // Create a deep copy of the current spaces for comparison
            let currentSpacesCopy = self.spaces
            
            // Check if there are any meaningful changes in spaces or windows
            let hasChanges = sortedSpaces != currentSpacesCopy
            
            if hasChanges {
                DispatchQueue.main.async {
                    self.spaces = sortedSpaces
                }
            }
        }
    }
    
    // MARK: - Space Actions
    
    /// Focuses the given space
    /// - Parameters:
    ///   - spaceId: ID of the space to focus
    ///   - needWindowFocus: Whether to also focus a window in the space
    func focusSpace(spaceId: String, needWindowFocus: Bool = false) {
        provider?.focusSpace(spaceId: spaceId, needWindowFocus: needWindowFocus)
    }
    
    /// Focuses the given window
    /// - Parameter windowId: ID of the window to focus
    func focusWindow(windowId: String) {
        provider?.focusWindow(windowId: windowId)
    }
}

// MARK: - Icon Cache

/// Cache for application icons
final class IconCache {
    static let shared = IconCache()
    private var cache: [String: NSImage] = [:]
    
    private init() {}
    
    /// Gets an icon for the given bundle identifier
    /// - Parameter bundleIdentifier: The bundle identifier to get an icon for
    /// - Returns: The app icon or nil if not found
    func getIcon(for bundleIdentifier: String) -> NSImage? {
        if let icon = cache[bundleIdentifier] {
            return icon
        }
        
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            cache[bundleIdentifier] = icon
            return icon
        }
        
        return nil
    }
}

