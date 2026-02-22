import AVFoundation
import MacroTesting
import PlaybackState
import SwiftSyntaxMacros
import Testing

extension PlaybackStateTests {
    @Test
    func playbackConditionTreatsFailedPayloadsAsEqual() throws {
        #if canImport(PlaybackStateMacroPlugin)
        let lhs = PlaybackConditionCoarseEqualityProbe.PlaybackCondition.failed(
            NSError(domain: "lhs", code: 1)
        )
        let rhs = PlaybackConditionCoarseEqualityProbe.PlaybackCondition.failed(
            NSError(domain: "rhs", code: 2)
        )

        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
        #else
        Issue.record("macros are only supported when running tests for the host platform")
        return
        #endif
    }

}
