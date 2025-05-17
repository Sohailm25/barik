import AppKit
import Combine
import Foundation

// MARK: - Playback State

/// Represents the current playback state.
enum PlaybackState: String {
    case playing, paused, stopped
}

// MARK: - Now Playing Song Model

/// Model representing the currently playing song.
struct NowPlayingSong: Equatable, Identifiable {
    var id: String { title + artist }
    let appName: String
    let appBundleIdentifier: String?
    let state: PlaybackState
    let title: String
    let artist: String
    let album: String
    let albumArtData: Data?
    let albumArtURL: URL?
    let position: Double?
    let duration: Double?  // Duration in seconds
    let timestamp: Date?

    func copyWith(
        appName: String? = nil,
        appBundleIdentifier: String?? = nil,
        state: PlaybackState? = nil,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumArtData: Data?? = nil,
        albumArtURL: URL?? = nil,
        position: Double?? = nil,
        duration: Double?? = nil,
        timestamp: Date?? = nil
    ) -> NowPlayingSong {
        return NowPlayingSong(
            appName: appName ?? self.appName,
            appBundleIdentifier: appBundleIdentifier != nil
                ? appBundleIdentifier! : self.appBundleIdentifier,
            state: state ?? self.state,
            title: title ?? self.title,
            artist: artist ?? self.artist,
            album: album ?? self.album,
            albumArtData: albumArtData != nil ? albumArtData! : self.albumArtData,
            albumArtURL: albumArtURL != nil ? albumArtURL! : self.albumArtURL,
            position: position != nil ? position! : self.position,
            duration: duration != nil ? duration! : self.duration,
            timestamp: timestamp != nil ? timestamp! : self.timestamp
        )
    }
}

// MARK: - Music Player

/// Represents supported music players.
private enum MusicPlayer: String {
    case music = "Music"
    case spotify = "Spotify"
    
    var bundleIdentifier: String {
        switch self {
        case .music: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        }
    }
    
    /// Playback control commands
    enum Command: String {
        case togglePlayPause = "playpause"
        case next = "next track"
        case previous = "previous track"
    }
}

// MARK: - Now Playing Provider

/// Provides functionality for retrieving current track information and controlling playback.
final class NowPlayingProvider {
    
    /// Checks if the specified app is running.
    private static func isAppRunning(_ bundleIdentifier: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    /// Executes an AppleScript and returns the result.
    private static func runAppleScript(script: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            print("AppleScript failed to compile script")
            return nil
        }
        
        let descriptor = appleScript.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript Error: \(error)")
        }
        return descriptor
    }

    /// Fetches now playing information from the specified player.
    private static func fetchNowPlayingInfoFromPlayer(_ player: MusicPlayer, completion: @escaping (NowPlayingSong?) -> Void) {
        let script: String
        
        switch player {
        case .music:
            script = """
            tell application "Music"
                if it is running then
                    if player state is playing or player state is paused then
                        set currentTrack to current track
                        set trackTitle to name of currentTrack
                        set trackArtist to artist of currentTrack
                        set trackAlbum to album of currentTrack
                        set trackDuration to duration of currentTrack
                        set playerPos to player position
                        set isPlaying to (player state is playing)
                        set artworkData to missing value
                        try
                            if (count of artworks of currentTrack) > 0 then
                               set artworkData to data of item 1 of artworks of currentTrack
                            end if
                        on error
                            set artworkData to missing value
                        end try
                        return {trackTitle, trackArtist, trackAlbum, trackDuration, playerPos, isPlaying, "\(player.bundleIdentifier)", artworkData}
                    end if
                end if
                return missing value
            end tell
            """
        case .spotify:
            script = """
            tell application "Spotify"
                if it is running then
                    if player state is playing or player state is paused then
                        set currentTrack to current track
                        set trackTitle to name of currentTrack
                        set trackArtist to artist of currentTrack
                        set trackAlbum to album of currentTrack
                        set trackDuration to duration of currentTrack / 1000.0
                        set playerPos to player position
                        set isPlaying to (player state is playing)
                        set artworkURLString to missing value
                        try
                            set artworkURLString to artwork url of currentTrack
                        end try
                        return {trackTitle, trackArtist, trackAlbum, trackDuration, playerPos, isPlaying, "\(player.bundleIdentifier)", artworkURLString}
                    end if
                end if
                return missing value
            end tell
            """
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let result = runAppleScript(script: script), result.descriptorType != 0x6D736E67 else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let title = result.atIndex(1)?.stringValue ?? ""
            let artist = result.atIndex(2)?.stringValue ?? ""
            
            // If no title and artist, assume no track is effectively playing or retrievable
            guard !title.isEmpty || !artist.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let album = result.atIndex(3)?.stringValue ?? ""
            let duration = result.atIndex(4)?.doubleValue ?? 0.0
            let position = result.atIndex(5)?.doubleValue
            let isPlaying = result.atIndex(6)?.booleanValue ?? false
            let bundleID = result.atIndex(7)?.stringValue ?? player.bundleIdentifier
            
            // Get the application name
            var appName = player.rawValue
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
               let appBundle = Bundle(url: appURL) {
                appName = appBundle.infoDictionary?["CFBundleName"] as? String ?? player.rawValue
            }

            let state: PlaybackState = isPlaying ? .playing : .paused
            var albumArtData: Data? = nil
            var albumArtURL: URL? = nil

            // Handle album artwork based on player type
            if player == .music, result.atIndex(8)?.descriptorType != 0x6D736E67 {
                albumArtData = result.atIndex(8)?.data
            } else if player == .spotify, result.atIndex(8)?.descriptorType != 0x6D736E67,
                      let artworkURLString = result.atIndex(8)?.stringValue,
                      let url = URL(string: artworkURLString) {
                albumArtData = try? Data(contentsOf: url)
            }
            
            if let artData = albumArtData {
                albumArtURL = saveArtworkToTemporaryFolder(title + artist + album, artData)
            }

            let song = NowPlayingSong(
                appName: appName,
                appBundleIdentifier: bundleID,
                state: state,
                title: title,
                artist: artist,
                album: album,
                albumArtData: albumArtData,
                albumArtURL: albumArtURL,
                position: position,
                duration: duration,
                timestamp: Date()
            )
            
            DispatchQueue.main.async {
                completion(song)
            }
        }
    }

    /// Fetches information about the currently playing track by checking multiple players.
    static func fetchNowPlaying(completion: @escaping (NowPlayingSong?) -> Void) {
        // Try Spotify first
        fetchNowPlayingInfoFromPlayer(.spotify) { spotifySong in
            if let song = spotifySong, (song.state == .playing || (!song.title.isEmpty && !song.artist.isEmpty)) {
                completion(song)
            } else {
                // Try Music if Spotify is not playing or has no info
                fetchNowPlayingInfoFromPlayer(.music) { musicSong in
                    if let song = musicSong, (song.state == .playing || (!song.title.isEmpty && !song.artist.isEmpty)) {
                        completion(song)
                    } else if let sSong = spotifySong, (!sSong.title.isEmpty && !sSong.artist.isEmpty) {
                        // If Spotify was paused but had valid info
                        completion(sSong)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }

    /// Saves artwork data to a temporary folder and returns the URL.
    static func saveArtworkToTemporaryFolder(_ artworkIdentifier: String, _ artworkData: Data) -> URL? {
        // Create a hash from identifier to avoid special characters in filename
        let safeFileName =
            artworkIdentifier
            .data(using: .utf8)?
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-") ?? "unknown_artwork"

        // Create a special directory for album covers
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let artworkDirectory = temporaryDirectory.appendingPathComponent(
            "NowPlayingArtwork", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: artworkDirectory.path) {
            try? FileManager.default.createDirectory(
                at: artworkDirectory,
                withIntermediateDirectories: true)
        }

        // Add .jpg extension for proper file handling
        let artworkURL = artworkDirectory.appendingPathComponent(safeFileName)
            .appendingPathExtension("jpg")

        // If file already exists, don't overwrite it
        if !FileManager.default.fileExists(atPath: artworkURL.path) {
            try? artworkData.write(to: artworkURL)
        }

        // Verify file exists before returning URL
        return FileManager.default.fileExists(atPath: artworkURL.path) ? artworkURL : nil
    }

    /// Determines which player is active based on bundle identifier.
    private static func determineActivePlayer(appBundleIdentifier: String?) -> MusicPlayer? {
        if let bundleId = appBundleIdentifier {
            if bundleId == MusicPlayer.music.bundleIdentifier {
                return .music
            } else if bundleId == MusicPlayer.spotify.bundleIdentifier {
                return .spotify
            }
        }
        
        // If no specific bundle ID, or an unknown one, try to see which one is running.
        // Prioritize Spotify if both are running, as it's checked first in fetchNowPlaying.
        if isAppRunning(MusicPlayer.spotify.bundleIdentifier) {
            return .spotify
        }
        if isAppRunning(MusicPlayer.music.bundleIdentifier) {
            return .music
        }
        return nil
    }
    
    /// Sends a command to the specified player.
    private static func sendCommandToPlayer(player: MusicPlayer, command: String) -> Bool {
        let script = "tell application \"\(player.rawValue)\" to \(command)"
        return runAppleScript(script: script) != nil
    }

    /// Executes play/pause command.
    static func togglePlayPause(appBundleIdentifier: String?) -> Bool {
        if let player = determineActivePlayer(appBundleIdentifier: appBundleIdentifier) {
            return sendCommandToPlayer(player: player, command: MusicPlayer.Command.togglePlayPause.rawValue)
        } else {
            // Fallback if no specific player or a generic request comes through.
            // Try Spotify first if running, then Music if running.
            var success = false
            if isAppRunning(MusicPlayer.spotify.bundleIdentifier) {
                success = sendCommandToPlayer(player: .spotify, command: MusicPlayer.Command.togglePlayPause.rawValue)
            }
            // If Spotify command wasn't attempted or failed, try Music.
            if !success && isAppRunning(MusicPlayer.music.bundleIdentifier) {
                success = sendCommandToPlayer(player: .music, command: MusicPlayer.Command.togglePlayPause.rawValue)
            }
            return success
        }
    }

    /// Executes next track command.
    static func nextTrack(appBundleIdentifier: String?) -> Bool {
        if let player = determineActivePlayer(appBundleIdentifier: appBundleIdentifier) {
            return sendCommandToPlayer(player: player, command: MusicPlayer.Command.next.rawValue)
        } else {
            var success = false
            if isAppRunning(MusicPlayer.spotify.bundleIdentifier) {
                success = sendCommandToPlayer(player: .spotify, command: MusicPlayer.Command.next.rawValue)
            }
            if !success && isAppRunning(MusicPlayer.music.bundleIdentifier) {
                success = sendCommandToPlayer(player: .music, command: MusicPlayer.Command.next.rawValue)
            }
            return success
        }
    }

    /// Executes previous track command.
    static func previousTrack(appBundleIdentifier: String?) -> Bool {
        if let player = determineActivePlayer(appBundleIdentifier: appBundleIdentifier) {
            return sendCommandToPlayer(player: player, command: MusicPlayer.Command.previous.rawValue)
        } else {
            var success = false
            if isAppRunning(MusicPlayer.spotify.bundleIdentifier) {
                success = sendCommandToPlayer(player: .spotify, command: MusicPlayer.Command.previous.rawValue)
            }
            if !success && isAppRunning(MusicPlayer.music.bundleIdentifier) {
                success = sendCommandToPlayer(player: .music, command: MusicPlayer.Command.previous.rawValue)
            }
            return success
        }
    }

    /// Sets playback position.
    static func seek(to position: Double, appBundleIdentifier: String?) -> Bool {
        let command = "set player position to \(position)"
        if let player = determineActivePlayer(appBundleIdentifier: appBundleIdentifier) {
            return sendCommandToPlayer(player: player, command: command)
        } else {
            var success = false
            if isAppRunning(MusicPlayer.spotify.bundleIdentifier) {
                success = sendCommandToPlayer(player: .spotify, command: command)
            }
            if !success && isAppRunning(MusicPlayer.music.bundleIdentifier) {
                success = sendCommandToPlayer(player: .music, command: command)
            }
            return success
        }
    }
}

// MARK: - Now Playing Manager

/// Observable manager that periodically updates information about the currently playing song.
final class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()

    @Published private(set) var nowPlaying: NowPlayingSong?
    private var cancellables = Set<AnyCancellable>()

    private var localToggled: Bool = false
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 0.5

    private init() {
        // Setup notification observers
        setupNotificationObservers()
        updateNowPlaying()
        setupUpdateTimer()
    }

    deinit {
        cancellables.removeAll()
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Private Methods
    
    /// Sets up system notification observers.
    private func setupNotificationObservers() {
        // System media notifications
        observeNotification(name: "kMRMediaRemoteNowPlayingInfoDidChangeNotification") { [weak self] in
            self?.updateNowPlaying()
        }

        observeNotification(name: "kMRMediaRemoteNowPlayingApplicationDidChangeNotification") { [weak self] in
            self?.updateNowPlaying()
        }

        // Player-specific notifications
        observeDistributedNotification(name: "com.spotify.client.PlaybackStateChanged") { [weak self] in
            self?.updateNowPlaying()
        }

        observeDistributedNotification(name: "com.apple.Music.playerInfo") { [weak self] in
            self?.updateNowPlaying()
        }
    }
    
    /// Configures the update timer with constant frequency.
    private func setupUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: updateInterval, 
            repeats: true
        ) { [weak self] _ in
            self?.updateNowPlaying()
        }
    }

    /// Updates information about the current track.
    private func updateNowPlaying() {
        // If local toggle is active, delay the request
        if localToggled {
            DispatchQueue.main.asyncAfter(deadline: .now() + (nowPlaying?.state == .playing ? 0 : 1)) { [weak self] in
                self?.fetchAndUpdatePlayingInfo()
            }
        } else {
            fetchAndUpdatePlayingInfo()
        }
    }
    
    /// Fetches and updates the playing information.
    private func fetchAndUpdatePlayingInfo() {
        NowPlayingProvider.fetchNowPlaying { [weak self] song in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.nowPlaying = song
                self.localToggled = false
                
                // Request again if information was not received
                if song == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.updateNowPlaying()
                    }
                }
            }
        }
    }

    /// Subscribes to system notification.
    private func observeNotification(name: String, handler: @escaping () -> Void) {
        NotificationCenter.default.publisher(for: NSNotification.Name(name))
            .sink { _ in handler() }
            .store(in: &cancellables)
    }

    /// Subscribes to distributed notification.
    private func observeDistributedNotification(name: String, handler: @escaping () -> Void) {
        DistributedNotificationCenter.default()
            .publisher(for: NSNotification.Name(name), object: nil)
            .sink { _ in handler() }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Control Methods

    /// Switches to the previous track.
    func previousTrack() {
        _ = NowPlayingProvider.previousTrack(appBundleIdentifier: nowPlaying?.appBundleIdentifier)
    }

    /// Toggles between play and pause states.
    func togglePlayPause() {
        // Switch local state
        let newPlaybackState: PlaybackState = nowPlaying?.state == .playing ? .paused : .playing
        nowPlaying = nowPlaying?.copyWith(state: newPlaybackState)
        localToggled = true

        // Toggle state in NowPlayingProvider
        _ = NowPlayingProvider.togglePlayPause(appBundleIdentifier: nowPlaying?.appBundleIdentifier)
    }

    /// Switches to the next track.
    func nextTrack() {
        _ = NowPlayingProvider.nextTrack(appBundleIdentifier: nowPlaying?.appBundleIdentifier)
    }

    /// Sets playback position.
    /// - Parameter progress: Value from 0 to 1, where 0 is the beginning of the track, 1 is the end.
    func seek(to progress: Double) {
        guard let currentSong = nowPlaying, 
              let duration = currentSong.duration, 
              duration > 0,
              progress >= 0 && progress <= 1
        else {
            return
        }

        let position = progress * duration
        nowPlaying = nowPlaying?.copyWith(position: position)
        NowPlayingProvider.seek(to: position, appBundleIdentifier: currentSong.appBundleIdentifier)
    }
}
