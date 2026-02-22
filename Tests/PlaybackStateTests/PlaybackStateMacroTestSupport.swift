import AVFoundation
import MacroTesting
import PlaybackState
import SwiftSyntaxMacros

#if canImport(PlaybackStateMacroPlugin)
import PlaybackStateMacroPlugin

let testMacros: [String: Macro.Type] = [
    "Observed": ObservedMarkerMacro.self,
    "PlaybackState": PlaybackStateMacro.self,
    "TimeObserver": TimeObserverMarkerMacro.self,
]

@PlaybackState
@MainActor
@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
final class PlaybackConditionCoarseEqualityProbe {
    let player: AVPlayer
}
#endif
