import AppKit
import Combine

// MARK: - Core Space Models

/// Protocol defining the basic structure of a space model
protocol SpaceModel: Identifiable, Equatable, Codable {
    associatedtype WindowType: WindowModel
    
    var id: String { get }
    var isFocused: Bool { get }
    var windows: [WindowType] { get }
}

/// Protocol defining the basic structure of a window model
protocol WindowModel: Identifiable, Equatable, Codable {
    var id: String { get }
    var title: String? { get }
    var appName: String? { get }
    var isFocused: Bool { get set }
    var appBundleIdentifier: String? { get }
}

// MARK: - Space Providers

/// Base protocol for space providers
protocol SpacesProvider {
     associatedtype SpaceType: SpaceModel
    
    func getSpacesWithWindows() -> [SpaceType]?
}

/// Protocol for providers that publish space events
protocol EventBasedSpacesProvider {
    /// Publisher for space events
    var spacesPublisher: AnyPublisher<SpaceEvent, Never> { get }
    
    /// Start observing space events
    func startObserving()
    
    /// Stop observing space events
    func stopObserving()
}

/// Protocol for providers that operate on a polling basis
protocol PollingBasedSpacesProvider: SpacesProvider {
    /// Polling interval in seconds
    var pollingInterval: TimeInterval { get }
}

/// Protocol for providers that allow switching between spaces
protocol SwitchableSpacesProvider: SpacesProvider {
    /// Focus the given space
    /// - Parameters:
    ///   - spaceId: ID of the space to focus
    ///   - needWindowFocus: Whether to also focus a window in the space
    func focusSpace(spaceId: String, needWindowFocus: Bool)
    
    /// Focus the given window
    /// - Parameter windowId: ID of the window to focus
    func focusWindow(windowId: String)
}

// MARK: - Space Events

/// Events that can be emitted by space providers
enum SpaceEvent {
    /// Initial state of spaces
    case initialState([AnySpace])
    /// Space focus has changed
    case focusChanged(String)
    /// Windows in a space have updated
    case windowsUpdated(String, [AnyWindow])
}

// MARK: - Type-Erased Models

/// Type-erased window model that can hold any window model type
struct AnyWindow: Identifiable, Equatable, Codable {
    let id: String
    let title: String?
    let appName: String?
    var isFocused: Bool
    let appBundleIdentifier: String?
    
    init<W: WindowModel>(_ window: W) {
        self.id = window.id
        self.title = window.title
        self.appName = window.appName
        self.isFocused = window.isFocused
        self.appBundleIdentifier = window.appBundleIdentifier
    }
    
    static func == (lhs: AnyWindow, rhs: AnyWindow) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.appName == rhs.appName &&
               lhs.isFocused == rhs.isFocused &&
               lhs.appBundleIdentifier == rhs.appBundleIdentifier
    }
}

/// Type-erased space model that can hold any space model type
struct AnySpace: Identifiable, Equatable {
    let id: String
    var isFocused: Bool
    let windows: [AnyWindow]
    
    init<S: SpaceModel>(_ space: S) {
        self.id = space.id
        self.isFocused = space.isFocused
        self.windows = space.windows.map { AnyWindow($0) }
    }
    
    init(id: String, isFocused: Bool, windows: [AnyWindow]) {
        self.id = id
        self.isFocused = isFocused
        self.windows = windows
    }
    
    static func == (lhs: AnySpace, rhs: AnySpace) -> Bool {
        return lhs.id == rhs.id && 
               lhs.isFocused == rhs.isFocused && 
               lhs.windows == rhs.windows
    }
}

// MARK: - Type-Erased Provider

/// Type-erased provider that can wrap any space provider
final class AnySpacesProvider {
    // MARK: - Private Properties
    
    private let _getSpacesWithWindows: () -> [AnySpace]?
    private let _focusSpace: ((String, Bool) -> Void)?
    private let _focusWindow: ((String) -> Void)?
    
    private let _isEventBased: Bool
    private let _isPollingBased: Bool
    private let _pollingInterval: TimeInterval
    private let _startObserving: (() -> Void)?
    private let _stopObserving: (() -> Void)?
    private let _spacesPublisher: AnyPublisher<SpaceEvent, Never>?
    
    // MARK: - Public Properties
    
    /// Whether this provider is event-based
    var isEventBased: Bool { _isEventBased }
    
    /// Whether this provider is polling-based
    var isPollingBased: Bool { _isPollingBased }
    
    /// Polling interval for this provider
    var pollingInterval: TimeInterval { _pollingInterval }
    
    /// Publisher for space events (if the provider is event-based)
    var spacesPublisher: AnyPublisher<SpaceEvent, Never>? { _spacesPublisher }
    
    // MARK: - Initialization
    
    /// Create a type-erased provider wrapping the given provider
    /// - Parameter provider: The provider to wrap
    init<P: SpacesProvider>(_ provider: P) {
        _getSpacesWithWindows = {
            provider.getSpacesWithWindows()?.map { AnySpace($0) }
        }
        
        // Handle switchable provider
        if let switchable = provider as? any SwitchableSpacesProvider {
            _focusSpace = { spaceId, needWindowFocus in
                switchable.focusSpace(
                    spaceId: spaceId,
                    needWindowFocus: needWindowFocus
                )
            }
            _focusWindow = switchable.focusWindow
        } else {
            _focusSpace = nil
            _focusWindow = nil
        }
        
        // Handle polling-based provider
        if let pollingBased = provider as? any PollingBasedSpacesProvider {
            _isPollingBased = true
            _pollingInterval = pollingBased.pollingInterval
        } else {
            _isPollingBased = false
            _pollingInterval = 0.1 // Default value
        }
        
        // Handle event-based provider
        if let eventBased = provider as? any EventBasedSpacesProvider {
            _isEventBased = true
            _startObserving = eventBased.startObserving
            _stopObserving = eventBased.stopObserving
            _spacesPublisher = eventBased.spacesPublisher
        } else {
            _isEventBased = false
            _startObserving = nil
            _stopObserving = nil
            _spacesPublisher = nil
        }
    }
    
    // MARK: - Public Methods
    
    /// Get spaces with their windows
    /// - Returns: Array of spaces with windows, or nil if unavailable
    func getSpacesWithWindows() -> [AnySpace]? {
        _getSpacesWithWindows()
    }
    
    /// Focus the given space
    /// - Parameters:
    ///   - spaceId: ID of the space to focus
    ///   - needWindowFocus: Whether to also focus a window in the space
    func focusSpace(spaceId: String, needWindowFocus: Bool = false) {
        _focusSpace?(spaceId, needWindowFocus)
    }
    
    /// Focus the given window
    /// - Parameter windowId: ID of the window to focus
    func focusWindow(windowId: String) {
        _focusWindow?(windowId)
    }
    
    /// Start observing space events (if the provider is event-based)
    func startObserving() {
        _startObserving?()
    }
    
    /// Stop observing space events (if the provider is event-based)
    func stopObserving() {
        _stopObserving?()
    }
}
