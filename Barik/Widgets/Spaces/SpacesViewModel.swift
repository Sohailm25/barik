import AppKit
import Combine
import Foundation

/// ViewModel for managing and displaying spaces
final class SpacesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current spaces with their windows
    @Published var spaces: [AnySpace] = []
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var provider: AnySpacesProvider?
    private var cancellables: Set<AnyCancellable> = []
    private var spacesById: [String: AnySpace] = [:]
    
    // MARK: - Initialization
    
    init() {
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
        provider = AnySpacesProvider(YabaiSpacesProvider())
        startMonitoring()
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
    
    /// Handles a space event from an event-based provider
    /// - Parameter event: The space event to handle
    private func handleSpaceEvent(_ event: SpaceEvent) {
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
                print("Spaces changed: \(sortedSpaces.count) spaces, \(sortedSpaces.reduce(0) { $0 + $1.windows.count }) windows")
                
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
