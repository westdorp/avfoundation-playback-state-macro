import AVFoundation
import MacroTesting
import PlaybackState
import SwiftSyntaxMacros
import Testing

extension PlaybackStateTests {
    @Test
    func playbackStateRejectsPreexistingSynthesizedInitializerSignature() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer

                /// Creates a playback monitor bound to the given player.
                ///
                /// - Parameter player: The `AVPlayer` instance to observe.
                init(player: AVPlayer) {
                    self.player = player
                }
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                        ┬──────────────
                        ╰─ 🛑 @PlaybackState cannot synthesize 'init(player:)' because it is already declared. The macro owns this initializer to wire derived state streams and observers. Remove the custom 'init(player:)' or remove @PlaybackState and manage wiring manually.
                let player: AVPlayer

                /// Creates a playback monitor bound to the given player.
                ///
                /// - Parameter player: The `AVPlayer` instance to observe.
                init(player: AVPlayer) {
                    self.player = player
                }
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }


    @Test
    func playbackStateRejectsUninitializedUnsupportedStoredProperties() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                let sessionID: String
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                        ┬──────────────
                        ╰─ 🛑 @PlaybackState cannot synthesize 'init(player:)' because stored property 'sessionID' is not initialized. The synthesized initializer can only assign managed macro properties and 'player'. Initialize this property inline or provide a custom initializer.
                let player: AVPlayer
                let sessionID: String
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func playbackStateUninitializedValidationOnlyFlagsUserDeclaredStoredProperties() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.rate) var rate: Float
                @TimeObserver(interval: .zero) var currentTime: CMTime
                let sessionID: String
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                        ┬──────────────
                        ╰─ 🛑 @PlaybackState cannot synthesize 'init(player:)' because stored property 'sessionID' is not initialized. The synthesized initializer can only assign managed macro properties and 'player'. Initialize this property inline or provide a custom initializer.
                let player: AVPlayer
                @Observed(.rate) var rate: Float
                @TimeObserver(interval: .zero) var currentTime: CMTime
                let sessionID: String
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }


}
