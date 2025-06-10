import SwiftUI

private let popupId = "nowplaying"

// MARK: - Now Playing Widget

struct NowPlayingWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject var playingManager = NowPlayingManager.shared

    @State private var widgetFrame: CGRect = .zero
    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        Button(action: {
            MenuBarPopup.show(rect: widgetFrame, id: popupId) {
                NowPlayingPopup(configProvider: configProvider)
            }
        }) {
            ZStack(alignment: .trailing) {
                if let song = playingManager.nowPlaying {
                    // Hidden view for measuring the intrinsic width.
                    MeasurableNowPlayingContent(song: song) { measuredWidth in
                        if animatedWidth == 0 {
                            animatedWidth = measuredWidth
                        } else if animatedWidth != measuredWidth {
                            withAnimation(.smooth) {
                                animatedWidth = measuredWidth
                            }
                        }
                    }
                    .hidden()

                    // Visible content with fixed animated width.
                    VisibleNowPlayingContent(song: song, width: animatedWidth)
                } else {
                    OutputAudioWidget(showBackground: false)
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            widgetFrame = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                            widgetFrame = newFrame
                        }
                }
            )
        }.buttonStyle(
            TransparentButtonStyle(withPadding: playingManager.nowPlaying != nil ? true : false))
    }
}

// MARK: - Now Playing Content

/// A view that composes the album art and song text into a capsule-shaped content view.
struct NowPlayingContent: View {
    let song: NowPlayingSong
    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }

    @State var isHovered: Bool = false

    var body: some View {
        VStack {
            if foregroundHeight < 38 {
                HStack(spacing: 8) {
                    AlbumArtView(song: song, isHovered: isHovered)
                    SongTextView(song: song)
                    OutputAudioWidget()
                }
            } else {
                HStack(spacing: 8) {
                    AlbumArtView(song: song, isHovered: isHovered)
                    SongTextView(song: song)
                    OutputAudioWidget()
                }
                .padding(.horizontal, foregroundHeight < 45 ? 6 : 8)
                .frame(height: foregroundHeight < 45 ? 30 : 38)
                
                .background(.noActive)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        GlassGradient.gradient,
                        lineWidth: 1
                    )
                )
            }
        }
        .foregroundColor(.foreground)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Measurable Now Playing Content

/// A wrapper view that measures the intrinsic width of the now playing content.
struct MeasurableNowPlayingContent: View {
    let song: NowPlayingSong
    let onSizeChange: (CGFloat) -> Void

    var body: some View {
        NowPlayingContent(song: song)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            onSizeChange(geometry.size.width)
                        }
                        .onChange(of: geometry.size.width) { _, newWidth in
                            onSizeChange(newWidth)
                        }
                }
            )
    }
}

// MARK: - Visible Now Playing Content

/// A view that displays now playing content with a fixed, animated width and transition.
struct VisibleNowPlayingContent: View {
    let song: NowPlayingSong
    let width: CGFloat

    var body: some View {
        NowPlayingContent(song: song)
            .frame(width: width, height: 38)
            .animation(.smooth(duration: 0.1), value: song)
            .transition(.blurReplace)
    }
}

// MARK: - Album Art View

/// A view that displays the album art with a fade animation and a pause indicator if needed.
struct AlbumArtView: View {
    let song: NowPlayingSong
    let isHovered: Bool

    var body: some View {
        Button(action: {
            NowPlayingManager.shared.togglePlayPause()
        }) {
            ZStack {
                FadeAnimatedCachedImage(
                    url: song.albumArtURL,
                    targetSize: CGSize(width: 20, height: 20),
                    fitHeight: true
                )
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .scaleEffect(song.state == .paused ? 0.9 : 1)
                .brightness(song.state == .paused || isHovered ? -0.3 : 0)

                if song.state == .paused {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.white)
                        .transition(.blurReplace)
                } else if isHovered {
                    PlayingStatus()
                }
            }
            .animation(.smooth(duration: 0.1), value: isHovered || song.state == .paused)
        }.buttonStyle(DefaultButtonStyle(withPadding: false, hoverStyle: .square))
    }
}

struct PlayingStatus: View {
    @State var musicAnimationValues = (0.0, 0.0, 0.0, 0.0, 0.0)

    var body: some View {
        HStack(spacing: 1) {
            Capsule()
                .fill(.white)
                .frame(width: 2, height: 13 * musicAnimationValues.0)
            Capsule()
                .fill(.white)
                .frame(width: 2, height: 13 * musicAnimationValues.1)
            Capsule()
                .fill(.white)
                .frame(width: 2, height: 13 * musicAnimationValues.2)
            Capsule()
                .fill(.white)
                .frame(width: 2, height: 13 * musicAnimationValues.3)
            Capsule()
                .fill(.white)
                .frame(width: 2, height: 13 * musicAnimationValues.4)
        }
        .onAppear {
            animation()
        }
        .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
            animation()
        }
    }

    func animation() {
        withAnimation(.linear(duration: 0.2)) {
            musicAnimationValues = (
                Double.random(in: 0.2...0.5),
                Double.random(in: 0.2...0.8),
                Double.random(in: 0.2...1),
                Double.random(in: 0.2...0.8),
                Double.random(in: 0.2...0.5)
            )
        }
    }
}

// MARK: - Song Text View

/// A view that displays the song title and artist.
struct SongTextView: View {
    let song: NowPlayingSong
    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }

    var body: some View {

        VStack(alignment: .leading, spacing: -1) {
            if foregroundHeight >= 30 {
                Text(song.title)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .padding(.trailing, 2)
                Text(song.artist)
                    .opacity(0.8)
                    .font(.system(size: 10))
                    .padding(.trailing, 2)
            } else {
                Text(song.artist + " — " + song.title)
                    .font(.system(size: 12))
            }
        }
        // Disable animations for text changes.
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

// MARK: - Preview

struct NowPlayingWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            NowPlayingWidget()
        }
        .frame(width: 500, height: 100)
    }
}
