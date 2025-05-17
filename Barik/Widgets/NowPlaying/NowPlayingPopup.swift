import EventKit
import SwiftUI

/// Прогресс-бар с возможностью перемотки
private struct SeekableProgressView: View {
    let position: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var dragProgress: Double?

    var body: some View {
        GeometryReader { geometry in
            ProgressView(value: dragProgress ?? position, total: duration)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = max(
                                0, min(1, value.location.x / geometry.size.width))
                            dragProgress = progress * duration
                        }
                        .onEnded { value in
                            let progress = max(
                                0, min(1, value.location.x / geometry.size.width))
                            dragProgress = nil
                            onSeek(progress)
                        }
                )
                .progressViewStyle(TrackProgressStyle())
        }.frame(height: 8.5)
    }
}

struct NowPlayingPopup: View {
    @ObservedObject var configProvider: ConfigProvider
    @State private var selectedVariant: MenuBarPopupVariant = .horizontal

    var body: some View {
        MenuBarPopupVariantView(
            selectedVariant: selectedVariant,
            onVariantSelected: { variant in
                selectedVariant = variant
                ConfigManager.shared.updateConfigValue(
                    key: "widgets.default.nowplaying.popup.view-variant",
                    newValue: variant.rawValue
                )
            },
            box: { NowPlayingBoxPopup() },
            vertical: { NowPlayingVerticalPopup() }
        )
        .onAppear(perform: loadVariant)
        .onReceive(configProvider.$config, perform: updateVariant)
    }

    /// Loads the initial view variant from configuration.
    private func loadVariant() {
        if let variantString = configProvider.config["popup"]?
            .dictionaryValue?["view-variant"]?.stringValue,
            let variant = MenuBarPopupVariant(rawValue: variantString)
        {
            selectedVariant = variant
        } else {
            selectedVariant = .box
        }
    }

    /// Updates the view variant when configuration changes.
    private func updateVariant(newConfig: ConfigData) {
        if let variantString = newConfig["popup"]?.dictionaryValue?["view-variant"]?.stringValue,
            let variant = MenuBarPopupVariant(rawValue: variantString)
        {
            selectedVariant = variant
        }
    }
}

/// A vertical layout for the now playing popup.
private struct NowPlayingVerticalPopup: View {
    @ObservedObject private var playingManager = NowPlayingManager.shared

    var body: some View {
        if let song = playingManager.nowPlaying,
            let duration = song.duration,
            let position = song.position
        {
            VStack(spacing: 15) {
                RotateAnimatedCachedImage(
                    url: song.albumArtURL,
                    targetSize: CGSize(width: 200, height: 200),
                    fitHeight: true
                ) { image in
                    image.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(width: 200, height: 200)
                .scaleEffect(song.state == .paused ? 0.9 : 1)
                .overlay(
                    song.state == .paused
                        ? Color.black.opacity(0.3)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        : nil
                )
                .animation(.smooth(duration: 0.5, extraBounce: 0.4), value: song.state == .paused)

                VStack(alignment: .center) {
                    Text(song.title)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15))
                        .fontWeight(.medium)
                    Text(song.artist)
                        .opacity(0.6)
                        .font(.system(size: 15))
                        .fontWeight(.light)
                }

                HStack {
                    Text(timeString(from: position))
                        .font(.caption)
                    SeekableProgressView(
                        position: position,
                        duration: duration,
                        onSeek: { progress in
                            playingManager.seek(to: progress)
                        }
                    )
                    Text("-" + timeString(from: duration - position))
                        .font(.caption)
                }
                .foregroundColor(.gray)
                .monospacedDigit()

                HStack(spacing: 20) {
                    Button(action: {
                        playingManager.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20))
                            .frame(width: 35, height: 35)
                    }
                    Button(action: {
                        playingManager.togglePlayPause()
                    }) {
                        Image(systemName: song.state == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 30))
                            .frame(width: 35, height: 35)
                    }
                    Button(action: {
                        playingManager.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .frame(width: 35, height: 35)
                    }
                }
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 30)
            .frame(width: 300)
            .animation(.easeInOut, value: song.albumArtURL)
        }
    }
}

/// A horizontal layout for the now playing popup.
struct NowPlayingBoxPopup: View {
    @ObservedObject private var playingManager = NowPlayingManager.shared

    var body: some View {
        if let song = playingManager.nowPlaying,
            let duration = song.duration,
            let position = song.position
        {
            VStack(spacing: 15) {
                HStack(spacing: 15) {
                    RotateAnimatedCachedImage(
                        url: song.albumArtURL,
                        targetSize: CGSize(width: 200, height: 200),
                        fitHeight: true
                    ) { image in
                        image.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .frame(width: 60, height: 60)
                    .scaleEffect(song.state == .paused ? 0.9 : 1)
                    .overlay(
                        song.state == .paused
                            ? Color.black.opacity(0.3)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            : nil
                    )
                    .animation(
                        .smooth(duration: 0.5, extraBounce: 0.4), value: song.state == .paused)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(song.title)
                            .font(.headline)
                            .fontWeight(.medium)
                        Text(song.artist)
                            .opacity(0.6)
                            .font(.headline)
                            .fontWeight(.light)
                    }
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Text(timeString(from: position))
                        .font(.caption)
                    SeekableProgressView(
                        position: position,
                        duration: duration,
                        onSeek: { progress in
                            playingManager.seek(to: progress)
                        }
                    )
                    Text("-" + timeString(from: duration - position))
                        .font(.caption)
                }
                .foregroundColor(.gray)
                .monospacedDigit()

                HStack(spacing: 20) {
                    Button(action: {
                        playingManager.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20))
                            .frame(width: 35, height: 35)
                    }
                    Button(action: {
                        playingManager.togglePlayPause()
                    }) {
                        Image(systemName: song.state == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 30))
                            .frame(width: 35, height: 35)
                    }
                    Button(action: {
                        playingManager.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .frame(width: 35, height: 35)
                    }
                }
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 20)
            .frame(width: 300, height: 180)
            .animation(.easeInOut, value: song.albumArtURL)
        }
    }
}

/// Converts a time interval in seconds to a formatted string (minutes:seconds).
private func timeString(from seconds: Double) -> String {
    let intSeconds = Int(seconds)
    let minutes = intSeconds / 60
    let remainingSeconds = intSeconds % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
}
