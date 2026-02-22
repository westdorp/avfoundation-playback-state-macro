import AVFoundation
import MacroTesting
import PlaybackState
import SwiftSyntaxMacros
import Testing

extension PlaybackStateTests {
    @Test
    func playbackStateRequiresMainActorIsolation() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            final class PlaybackMonitor {
                let player: AVPlayer
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            final class PlaybackMonitor {
                        ┬──────────────
                        ╰─ 🛑 @PlaybackState requires @MainActor isolation. Observation callbacks mutate derived playback state and must serialize on the main actor. Annotate the type with '@MainActor'.
                           ✏️ Add '@MainActor' attribute
                let player: AVPlayer
            }
            """
        } fixes: {
            """
            @MainActor
            @PlaybackState
            final class PlaybackMonitor {
                let player: AVPlayer
            }
            """
        } expansion: {
            #"""
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer

            \#(expectedPlaybackConditionEnumExpansion())

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
            """#
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }


}
