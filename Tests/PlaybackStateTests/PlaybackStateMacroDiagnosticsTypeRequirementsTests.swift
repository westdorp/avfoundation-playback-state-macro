import AVFoundation
import MacroTesting
import PlaybackState
import SwiftSyntaxMacros
import Testing

extension PlaybackStateTests {
    @Test
    func playbackStateRequiresFinalClass() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            struct PlaybackMonitor {}
            """
        } diagnostics: {
            """
            @PlaybackState
            ╰─ 🛑 @PlaybackState can only be applied to a final class. The macro owns mutable observation lifecycle state that requires stable reference identity. Apply @PlaybackState to a declaration like '@MainActor final class PlaybackMonitor { let player: AVPlayer }'.
            struct PlaybackMonitor {}
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func playbackStateAddsFinalFixItForClass() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            class PlaybackMonitor {
                let player: AVPlayer
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            class PlaybackMonitor {
                  ┬──────────────
                  ╰─ 🛑 @PlaybackState can only be applied to a final class. The macro owns mutable observation lifecycle state that requires stable reference identity. Add the 'final' modifier to this class declaration.
                     ✏️ Add 'final' modifier
                let player: AVPlayer
            }
            """
        } fixes: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
            }
            """
        } expansion: {
            """
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer

            \(expectedPlaybackConditionEnumExpansion())

                /// The most recently derived playback condition.
                ///
                /// Updated automatically when observed AVPlayer properties change.
                private(set) var playbackCondition: PlaybackCondition = .unknown {
                    didSet {
                        guard oldValue != playbackCondition else {
                            return
                        }
                        _playbackContinuation.yield(playbackCondition)
                    }
                }

                private func _derivePlaybackCondition() -> PlaybackCondition {
                    guard player.currentItem != nil else {
                        return .idle
                    }

                    switch player.currentItem?.status {
                    case .failed:
                        return .failed(player.currentItem?.error)
                    case .unknown:
                        return .loading
                    case .readyToPlay:
                        switch player.timeControlStatus {
                        case .paused:
                            return player.rate == 0 ? .paused : .scrubbing
                        case .waitingToPlayAtSpecifiedRate:
                            return .buffering(reason: player.reasonForWaitingToPlay)
                        case .playing:
                            return .playing(rate: player.rate)
                        @unknown default:
                            return .unknown
                        }
                    case .none:
                        return .idle
                    @unknown default:
                        return .unknown
                    }
                }

                private func _beginObservation() {
                    Observation.withObservationTracking {
                        _ = player.timeControlStatus
                        _ = player.rate
                        _ = player.reasonForWaitingToPlay
                        _ = player.currentItem
                        _ = player.currentItem?.status
                        _ = player.currentItem?.error
                        _ = player.currentItem?.isPlaybackBufferEmpty
                    } onChange: { [weak self] in
                        Task { @MainActor [weak self] in
                            guard let self else {
                                return
                            }
                            // Re-arm observation because Observation.withObservationTracking triggers only once per change.
                            self.playbackCondition = self._derivePlaybackCondition()
                            self._beginObservation()
                        }
                    }
                }

                /// A stream of playback condition changes.
                ///
                /// Each element represents a new condition distinct from the previous one.
                let playbackConditions: AsyncStream<PlaybackCondition>

                private let _playbackContinuation: AsyncStream<PlaybackCondition>.Continuation

                private var _timeObserverTokens: [Any] = []

                /// Creates a playback monitor bound to the given player.
                ///
                /// - Parameter player: The `AVPlayer` instance to observe.
                init(player: AVPlayer) {
                    self.player = player
                    let (playbackConditions, playbackContinuation) = AsyncStream<PlaybackCondition>.makeStream()
                    self.playbackConditions = playbackConditions
                    self._playbackContinuation = playbackContinuation
                    self.playbackCondition = self._derivePlaybackCondition()
                    self._playbackContinuation.yield(self.playbackCondition)
                    self._beginObservation()
                }

                /// Tears down time-observer tokens and finishes the playback conditions stream.
                isolated deinit {
                    for token in _timeObserverTokens {
                        player.removeTimeObserver(token)
                    }
                    _playbackContinuation.finish()
                }
            }

            extension PlaybackMonitor: Sendable {
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func playbackStateRequiresPlayerProperty() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {}
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {}
                        ┬──────────────
                        ╰─ 🛑 @PlaybackState requires a stored instance property 'let player: AVPlayer'. PlaybackCondition derivation reads AVPlayer surfaces from this property. Add 'let player: AVPlayer'.
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func playbackStateRejectsStaticPlayerProperty() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                static let player: AVPlayer
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                        ┬──────────────
                        ╰─ 🛑 @PlaybackState requires a stored instance property 'let player: AVPlayer'. PlaybackCondition derivation reads AVPlayer surfaces from this property. Add 'let player: AVPlayer'.
                static let player: AVPlayer
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }



}
