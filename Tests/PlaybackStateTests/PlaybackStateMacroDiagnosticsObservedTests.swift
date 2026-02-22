import AVFoundation
import MacroTesting
import PlaybackState
import SwiftSyntaxMacros
import Testing

extension PlaybackStateTests {
    @Test
    func observedRejectsUnknownCase() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.bogusKeyPath) var rate: Float
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.bogusKeyPath) var rate: Float
                ┬───────────────────────
                ╰─ 🛑 Unrecognized ObservedKeyPath case '.bogusKeyPath'. @Observed only accepts supported derivation inputs. Use a supported case such as @Observed(.rate).
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func observedRequiresObservedKeyPathCase() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(PlaybackKeys.rate) var rate: Float
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(PlaybackKeys.rate) var rate: Float
                ┬───────────────────────────
                ╰─ 🛑 @Observed requires an ObservedKeyPath case. @Observed defines which AVPlayer surfaces feed PlaybackCondition derivation. Use a supported case such as @Observed(.rate).
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func playbackStateRejectsDuplicateObservedCanonicalKeyPaths() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.currentItemStatus) var itemStatus: AVPlayerItem.Status?
                @Observed(.currentItemStatus) var canonicalDuplicateStatus: AVPlayerItem.Status?
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.currentItemStatus) var itemStatus: AVPlayerItem.Status?
                @Observed(.currentItemStatus) var canonicalDuplicateStatus: AVPlayerItem.Status?
                                                  ┬───────────────────────
                                                  ╰─ 🛑 @PlaybackState can observe key path 'currentItem.status' only once. Duplicate canonical inputs make PlaybackCondition derivation ambiguous. Remove one duplicated @Observed declaration for 'currentItem.status'.
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func observedRequiresExpectedPropertyTypeForKeyPath() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.rate) var rate: Int
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.rate) var rate: Int
                                     ┬───
                                     ╰─ 🛑 @Observed key path 'rate' requires property type 'Float' (found 'Int'). PlaybackCondition derivation relies on canonical AVPlayer surface types. Change the property type to 'Float' for this key path.
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func observedTypeMismatchDiagnosticUsesCanonicalKeyPath() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.currentItemIsPlaybackBufferEmpty) var bufferEmpty: Bool
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.currentItemIsPlaybackBufferEmpty) var bufferEmpty: Bool
                                                                 ┬──────────
                                                                 ╰─ 🛑 @Observed key path 'currentItem.isPlaybackBufferEmpty' requires property type 'Bool?' (found 'Bool'). PlaybackCondition derivation relies on canonical AVPlayer surface types. Change the property type to 'Bool?' for this key path.
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }


}
