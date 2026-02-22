/// Shared fixture for expected `PlaybackCondition` enum expansion output.
func expectedPlaybackConditionEnumExpansion() -> String {
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
