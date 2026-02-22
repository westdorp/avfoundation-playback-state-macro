import Foundation
import PlaybackStateMacroPluginUtilities
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension ObservedMarkerMacro {
    /// Extracts the enum case name argument from an `@Observed` attribute.
    static func observedKeyPathCaseName(from attribute: AttributeSyntax) -> String? {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
              let firstArgument = arguments.first
        else {
            return nil
        }

        guard let memberAccess = firstArgument.expression.as(MemberAccessExprSyntax.self) else {
            return nil
        }

        let caseName = memberAccess.declName.baseName.text

        guard let base = memberAccess.base else {
            return caseName
        }

        let baseText = base.trimmedDescription
        if baseText == "ObservedKeyPath" || baseText.hasSuffix(".ObservedKeyPath") {
            return caseName
        }

        return nil
    }
}
