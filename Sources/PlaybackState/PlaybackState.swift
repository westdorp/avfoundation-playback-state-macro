import CoreMedia

/// Stable marker namespace for the `PlaybackState` module.
///
/// Use this type when you need a concrete symbol reference to verify module linking
/// without triggering macro expansion.
public enum PlaybackStateModule: Sendable {
    /// Human-readable module identifier for compile-time integration checks.
    public static let name = "PlaybackState"
}

/// Supported AVPlayer inputs for `@Observed`.
@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
public enum ObservedKeyPath: Sendable {
    case rate
    case timeControlStatus
    case reasonForWaitingToPlay
    case currentItemStatus
    case currentItemIsPlaybackBufferEmpty
    case currentItemError
}

/// Generates playback-condition derivation and observation plumbing for `AVPlayer`.
///
/// Use this macro to hide multi-signal AVFoundation observation behind one value-semantic
/// `playbackCondition` surface and one async stream.
///
/// ```swift
/// @PlaybackState
/// @MainActor
/// final class PlayerObservation {
///     let player: AVPlayer
///
///     @Observed(.rate)
///     private var rate: Float = 0
///
///     @Observed(.timeControlStatus)
///     private var timeControlStatus: AVPlayer.TimeControlStatus = .paused
///
///     @TimeObserver(interval: CMTime(seconds: 0.5, preferredTimescale: 600))
///     private var currentTime: CMTime = .zero
/// }
/// ```
///
/// Role map:
/// - `player`: Source `AVPlayer` used to derive snapshots.
/// - `@Observed`: AVPlayer key-path inputs for derivation.
/// - `@TimeObserver`: Periodic timeline input.
/// - `playbackCondition`: Latest derived condition.
/// - `playbackConditions`: Stream of condition changes.
///
/// Contract:
/// - Apply to a `@MainActor final class`.
/// - Declare a stored `let player: AVPlayer`.
/// - `@Observed` accepts supported `ObservedKeyPath` cases such as `.rate`.
/// - `@TimeObserver` only applies to mutable `CMTime` stored properties and requires `interval:`.
@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
// `names:` must list every synthesized symbol, including underscored implementation details.
@attached(member, names: named(PlaybackCondition), named(playbackCondition), named(playbackConditions), named(_playbackContinuation), named(_timeObserverTokens), named(_derivePlaybackCondition), named(_beginObservation), named(init), named(deinit))
@attached(extension, conformances: Sendable)
public macro PlaybackState() = #externalMacro(
    module: "PlaybackStateMacroPlugin",
    type: "PlaybackStateMacro"
)

/// Marks a property as an observed AVPlayer key-path input for `@PlaybackState`.
///
/// Use a supported `ObservedKeyPath` case such as `.rate` or `.timeControlStatus`.
///
/// - Parameter keyPath: Supported `AVPlayer` surface to observe.
@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
@attached(peer)
public macro Observed(_ keyPath: ObservedKeyPath) = #externalMacro(
    module: "PlaybackStateMacroPlugin",
    type: "ObservedMarkerMacro"
)

/// Marks a mutable `CMTime` property as a periodic time-observer input for `@PlaybackState`.
///
/// Declare an explicit interval so periodic observation cadence remains deterministic.
///
/// - Parameter interval: Callback cadence used for `addPeriodicTimeObserver`.
@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
@attached(peer)
public macro TimeObserver(interval: CMTime) = #externalMacro(
    module: "PlaybackStateMacroPlugin",
    type: "TimeObserverMarkerMacro"
)
