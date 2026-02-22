import AVFoundation
import MacroTesting
import PlaybackState
import SwiftSyntaxMacros
import Testing

extension PlaybackStateTests {
    @Test
    func playbackStateGeneratesDerivationUsingObservedProperties() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(.timeControlStatus) var timeControlStatus: AVPlayer.TimeControlStatus
                @Observed(.rate) var rate: Float
                @Observed(.currentItemStatus) var itemStatus: AVPlayerItem.Status?
                @Observed(.currentItemIsPlaybackBufferEmpty) var isPlaybackBufferEmpty: Bool?
                @Observed(.reasonForWaitingToPlay) var waitingReason: AVPlayer.WaitingReason?
                @Observed(.currentItemError) var itemError: Error?
            }
            """
        } expansion: {
            """
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                var timeControlStatus: AVPlayer.TimeControlStatus
                var rate: Float
                var itemStatus: AVPlayerItem.Status?
                var isPlaybackBufferEmpty: Bool?
                var waitingReason: AVPlayer.WaitingReason?
                var itemError: Error?

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

                    switch itemStatus {
                    case .failed:
                        return .failed(itemError)
                    case .unknown:
                        return .loading
                    case .readyToPlay:
                        switch timeControlStatus {
                        case .paused:
                            return rate == 0 ? .paused : .scrubbing
                        case .waitingToPlayAtSpecifiedRate:
                            return .buffering(reason: waitingReason)
                        case .playing:
                            return .playing(rate: rate)
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
                            self.timeControlStatus = self.player.timeControlStatus
                            self.rate = self.player.rate
                            self.itemStatus = self.player.currentItem?.status
                            self.isPlaybackBufferEmpty = self.player.currentItem?.isPlaybackBufferEmpty
                            self.waitingReason = self.player.reasonForWaitingToPlay
                            self.itemError = self.player.currentItem?.error
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
                    self.timeControlStatus = player.timeControlStatus
                    self.rate = player.rate
                    self.itemStatus = player.currentItem?.status
                    self.isPlaybackBufferEmpty = player.currentItem?.isPlaybackBufferEmpty
                    self.waitingReason = player.reasonForWaitingToPlay
                    self.itemError = player.currentItem?.error
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
    func playbackStateRefreshesObservedPropertiesBeforeRederivation() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @Observed(ObservedKeyPath.rate) var rate: Float
            }
            """
        } expansion: {
            """
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                var rate: Float

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
                            return rate == 0 ? .paused : .scrubbing
                        case .waitingToPlayAtSpecifiedRate:
                            return .buffering(reason: player.reasonForWaitingToPlay)
                        case .playing:
                            return .playing(rate: rate)
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
                            self.rate = self.player.rate
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
                    self.rate = player.rate
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


}
