import SwiftDiagnostics

/// A reusable diagnostic payload for macro validations.
public struct MacroDiagnosticMessage: DiagnosticMessage {
    public let message: String
    public let diagnosticID: MessageID
    public let severity: DiagnosticSeverity = .error

    public init(_ message: String, domain: String, id: String) {
        self.message = message
        self.diagnosticID = MessageID(domain: domain, id: id)
    }
}

/// A reusable fix-it payload for macro validations.
public struct MacroFixItMessage: FixItMessage {
    public let message: String
    public let fixItID: MessageID

    public init(_ message: String, domain: String) {
        self.message = message
        self.fixItID = MessageID(domain: domain, id: message)
    }
}

/// Builds a concise diagnostic sentence from `what`, optional `why`, and optional `how`.
///
/// This keeps messaging format consistent across macro plugins while allowing each plugin
/// to provide domain-specific content.
public enum MacroDiagnosticText {
    /// Composes a diagnostic message in `what + why + how` order.
    ///
    /// Empty optional fragments are ignored.
    /// Each fragment has interior whitespace normalized to single spaces.
    public static func compose(
        what: String,
        why: String? = nil,
        how: String? = nil
    ) -> String {
        [what, why, how]
            .compactMap { fragment in
                guard let fragment else {
                    return nil
                }

                let normalized = fragment
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
                return normalized.isEmpty ? nil : normalized
            }
            .joined(separator: " ")
    }
}
