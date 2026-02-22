import Foundation
import PlaybackStateMacroPluginUtilities
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension PlaybackStateMacro {
    static func buildInitializerDeclaration(
        observedProperties: [ObservedProperty],
        timeObserverProperties: [TimeObserverProperty]
    ) -> String {
        let observedAssignments = observedProperties.map { property in
            "    self.\(property.name) = \(property.sourceExpression)"
        }.joined(separator: "\n")

        let timeObserverAssignments = timeObserverProperties.map { property in
            "    self.\(property.name) = player.currentTime()"
        }.joined(separator: "\n")

        let timeObserverRegistrations = timeObserverProperties.map { property in
            buildTimeObserverRegistration(for: property)
        }.joined(separator: "\n")

        let dynamicAssignments = [observedAssignments, timeObserverAssignments]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return """
        /// Creates a playback monitor bound to the given player.
        ///
        /// - Parameter player: The `AVPlayer` instance to observe.
        init(player: AVPlayer) {
            self.player = player
            let (playbackConditions, playbackContinuation) = AsyncStream<PlaybackCondition>.makeStream()
            self.playbackConditions = playbackConditions
            self._playbackContinuation = playbackContinuation\(dynamicAssignments.isEmpty ? "" : "\n\(dynamicAssignments)")
            self.playbackCondition = self._derivePlaybackCondition()
            self._playbackContinuation.yield(self.playbackCondition)\(timeObserverRegistrations.isEmpty ? "" : "\n\(timeObserverRegistrations)")
            self._beginObservation()
        }
        """
    }

    static func buildTimeObserverRegistration(for property: TimeObserverProperty) -> String {
        let tokenIdentifier = tokenIdentifier(for: property.name)
        return """
            let \(tokenIdentifier) = player.addPeriodicTimeObserver(forInterval: \(property.intervalExpression), queue: .main) { [weak self] time in
                Task { @MainActor [weak self, time] in
                    guard let self else {
                        return
                    }
                    self.\(property.name) = time
                    self.playbackCondition = self._derivePlaybackCondition()
                }
            }
            self._timeObserverTokens.append(\(tokenIdentifier))
        """
    }

    static func buildPlaybackConditionPropertyDeclaration() -> String {
        """
        /// The most recently derived playback condition.
        ///
        /// Updated automatically when observed AVPlayer properties change.
        private(set) var playbackCondition: PlaybackCondition = .unknown {
            didSet {
                guard oldValue != playbackCondition else { return }
                _playbackContinuation.yield(playbackCondition)
            }
        }
        """
    }

    static func buildPlaybackConditionEnumDeclaration() -> String {
        """
        /// A value describing the current playback condition derived from AVPlayer state.
        enum PlaybackCondition: Sendable, Hashable, CustomStringConvertible {
            /// No current item is loaded in the player.
            case idle
            /// The current item's status is unknown; metadata is loading.
            case loading
            /// The player is actively playing content at the given rate.
            case playing(rate: Float)
            /// The player is paused with a zero rate.
            case paused
            /// The player is waiting to play; the associated value captures the waiting reason.
            case buffering(reason: AVPlayer.WaitingReason?)
            /// The player is paused but has a non-zero rate (seeking).
            case scrubbing
            /// The current item encountered an error.
            case failed(Error?)
            /// The playback state could not be determined.
            case unknown

            static func == (lhs: PlaybackCondition, rhs: PlaybackCondition) -> Bool {
                switch (lhs, rhs) {
                case (.idle, .idle), (.loading, .loading), (.paused, .paused), (.scrubbing, .scrubbing), (.unknown, .unknown):
                    return true
                case let (.playing(leftRate), .playing(rightRate)):
                    return leftRate == rightRate
                case (.buffering, .buffering), (.failed, .failed):
                    return true
                default:
                    return false
                }
            }

            func hash(into hasher: inout Hasher) {
                switch self {
                case .idle:
                    hasher.combine(0)
                case .loading:
                    hasher.combine(1)
                case let .playing(rate):
                    hasher.combine(2)
                    hasher.combine(rate)
                case .paused:
                    hasher.combine(3)
                case .buffering:
                    hasher.combine(4)
                case .scrubbing:
                    hasher.combine(5)
                case .failed:
                    hasher.combine(6)
                case .unknown:
                    hasher.combine(7)
                }
            }

            var description: String {
                switch self {
                case .idle:
                    return "idle"
                case .loading:
                    return "loading"
                case let .playing(rate):
                    return "playing(rate: \\(rate))"
                case .paused:
                    return "paused"
                case let .buffering(reason):
                    return "buffering(reason: \\(String(describing: reason)))"
                case .scrubbing:
                    return "scrubbing"
                case let .failed(error):
                    return "failed(\\(String(describing: error)))"
                case .unknown:
                    return "unknown"
                }
            }
        }
        """
    }

    static func buildDerivePlaybackConditionDeclaration(
        observedProperties: [ObservedProperty]
    ) -> String {
        let itemStatus = observedSourceExpression(for: "currentItem.status", in: observedProperties) ?? "player.currentItem?.status"
        let timeControl = observedSourceExpression(for: "timeControlStatus", in: observedProperties) ?? "player.timeControlStatus"
        let rate = observedSourceExpression(for: "rate", in: observedProperties) ?? "player.rate"
        let waitingReason = observedSourceExpression(for: "reasonForWaitingToPlay", in: observedProperties) ?? "player.reasonForWaitingToPlay"
        let error = observedSourceExpression(for: "currentItem.error", in: observedProperties) ?? "player.currentItem?.error"

        return """
        private func _derivePlaybackCondition() -> PlaybackCondition {
            guard player.currentItem != nil else {
                return .idle
            }

            switch \(itemStatus) {
            case .failed:
                return .failed(\(error))
            case .unknown:
                return .loading
            case .readyToPlay:
                switch \(timeControl) {
                case .paused:
                    return \(rate) == 0 ? .paused : .scrubbing
                case .waitingToPlayAtSpecifiedRate:
                    return .buffering(reason: \(waitingReason))
                case .playing:
                    return .playing(rate: \(rate))
                @unknown default:
                    return .unknown
                }
            case .none:
                return .idle
            @unknown default:
                return .unknown
            }
        }
        """
    }

    static func buildBeginObservationDeclaration(
        observedProperties: [ObservedProperty]
    ) -> String {
        let refreshAssignments = observedProperties.map { property in
            let refreshExpression = refreshSourceExpression(for: property.sourceExpression)
            return "            self.\(property.name) = \(refreshExpression)"
        }.joined(separator: "\n")

        // Track all derivation inputs so _derivePlaybackCondition() always sees fresh player state,
        // even when some inputs are not represented as @Observed properties.
        return """
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
                    }\(refreshAssignments.isEmpty ? "" : "\n\(refreshAssignments)")
                    // Re-arm observation because Observation.withObservationTracking triggers only once per change.
                    self.playbackCondition = self._derivePlaybackCondition()
                    self._beginObservation()
                }
            }
        }
        """
    }

    static func observedSourceExpression(
        for keyPath: String,
        in observedProperties: [ObservedProperty]
    ) -> String? {
        observedProperties.first { property in
            property.keyPath == keyPath
        }?.name
    }

    static func refreshSourceExpression(for sourceExpression: String) -> String {
        // Prefix player reads with `self` so closure capture remains explicit and unambiguous.
        if sourceExpression == "player" {
            return "self.player"
        }

        if sourceExpression.hasPrefix("player.") {
            return "self.\(sourceExpression)"
        }

        return sourceExpression
    }

    static func tokenIdentifier(for propertyName: String) -> String {
        let sanitized = propertyName.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "_"
        }
        return "_\(String(sanitized))ObserverToken"
    }
}
