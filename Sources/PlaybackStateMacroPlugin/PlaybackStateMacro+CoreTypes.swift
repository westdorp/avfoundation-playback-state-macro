import Foundation
import PlaybackStateMacroPluginUtilities
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension PlaybackStateMacro {
    /// Parsed `@Observed` property metadata used for code generation.
    struct ObservedProperty {
        let name: String
        let keyPath: String
        let sourceExpression: String
    }

    /// An `@Observed` declaration whose property type disagrees with key-path requirements.
    struct ObservedTypeMismatch {
        let node: Syntax
        let keyPath: String
        let expectedType: String
        let actualType: String
    }

    /// A duplicate canonical `@Observed` key-path declaration.
    struct ObservedDuplicateKeyPath {
        let node: Syntax
        let keyPath: String
    }

    /// Parsed `@TimeObserver` property metadata used for registration code generation.
    struct TimeObserverProperty {
        let name: String
        let intervalExpression: String
    }
}
