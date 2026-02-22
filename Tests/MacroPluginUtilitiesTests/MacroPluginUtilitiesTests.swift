import PlaybackStateMacroPluginUtilities
import SwiftParser
import SwiftSyntax
import Testing

@Suite("Macro Plugin Utilities", .tags(.macro))
struct MacroPluginUtilitiesTests {
    @Test("Compose uses WHAT when WHY and HOW are missing")
    func composeUsesWhatOnlyWhenOptionalSegmentsAreMissing() {
        let message = MacroDiagnosticText.compose(
            what: "State enum is required."
        )

        #expect(message == "State enum is required.")
    }

    @Test(
        "Compose joins non-empty segments in WHAT-WHY-HOW order",
        arguments: [
            (
                what: "State enum is required.",
                why: "The state machine needs a finite state domain.",
                how: "Add nested enum State { ... }.",
                expected: "State enum is required. The state machine needs a finite state domain. Add nested enum State { ... }."
            ),
            (
                what: "Event marker is missing.",
                why: "   ",
                how: "\nAdd @PlaybackInput.\n",
                expected: "Event marker is missing. Add @PlaybackInput."
            ),
        ]
    )
    func composeNormalizesAndJoinsSegments(
        what: String,
        why: String?,
        how: String?,
        expected: String
    ) {
        let message = MacroDiagnosticText.compose(
            what: what,
            why: why,
            how: how
        )

        #expect(message == expected)
    }

    @Test("Sendable detection finds same-file extension conformance")
    func hasSendableConformanceFindsSameFileExtension() {
        let source = Parser.parse(
            source: """
            final class PlaybackMonitor {}
            extension PlaybackMonitor: Sendable {}
            """
        )

        let classDecl = source.statements
            .compactMap { statement in
                statement.item.as(ClassDeclSyntax.self)
            }
            .first
        #expect(classDecl != nil)
        guard let classDecl else {
            return
        }

        #expect(hasSendableConformance(in: classDecl))
    }
}
