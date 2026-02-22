import AVFoundation
import MacroTesting
import PlaybackState
import SwiftSyntaxMacros
import Testing

extension PlaybackStateTests {
    @Test
    func timeObserverRequiresCMTimeProperty() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @TimeObserver(interval: .zero) var currentTime: Double
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @TimeObserver(interval: .zero) var currentTime: Double
                ┬─────────────────────────────
                ╰─ 🛑 @TimeObserver requires a 'CMTime' property. Periodic observer updates must store time values. Change the property type to CMTime.
            }
            """
        } expansion: {
            """
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func timeObserverRequiresMutableVarProperty() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @TimeObserver(interval: .zero) let currentTime: CMTime = .zero
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @TimeObserver(interval: .zero) let currentTime: CMTime = .zero
                ┬─────────────────────────────
                ╰─ 🛑 @TimeObserver requires a mutable 'var CMTime' property. The macro writes periodic timestamps into this property. Change 'let' to 'var'.
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func timeObserverRequiresIntervalArgument() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @TimeObserver var currentTime: CMTime
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @TimeObserver var currentTime: CMTime
                ┬────────────
                ╰─ 🛑 @TimeObserver requires an explicit 'interval' argument (for example: @TimeObserver(interval: .seconds(0.5))). Explicit cadence keeps periodic observation deterministic. Add an interval argument such as '@TimeObserver(interval: .seconds(0.5))'.
            }
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

    @Test
    func playbackStateSkipsGenerationWhenAnyTimeObserverAttributeMissesInterval() throws {
        #if canImport(PlaybackStateMacroPlugin)
        assertMacro(testMacros) {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @TimeObserver
                @TimeObserver(interval: .zero)
                var currentTime: CMTime
            }
            """
        } diagnostics: {
            """
            @PlaybackState
            @MainActor
            final class PlaybackMonitor {
                let player: AVPlayer
                @TimeObserver
                ┬────────────
                ╰─ 🛑 @TimeObserver requires an explicit 'interval' argument (for example: @TimeObserver(interval: .seconds(0.5))). Explicit cadence keeps periodic observation deterministic. Add an interval argument such as '@TimeObserver(interval: .seconds(0.5))'.
                @TimeObserver(interval: .zero)
                var currentTime: CMTime
            }
            """
        } expansion: {
            """
            """
        }
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }


}
