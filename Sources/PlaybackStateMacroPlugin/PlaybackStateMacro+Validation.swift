import Foundation
import PlaybackStateMacroPluginUtilities
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension PlaybackStateMacro {
    private struct ValidationSummary {
        let isFinalClass: Bool
        let hasMainActorIsolation: Bool
        let hasRequiredPlayerProperty: Bool
        let hasInvalidObservedProperty: Bool
        let observedTypeMismatches: [ObservedTypeMismatch]
        let duplicateObservedKeyPaths: [ObservedDuplicateKeyPath]
        let hasImmutableTimeObserverViolation: Bool
        let hasMissingTimeObserverIntervalViolation: Bool
        let hasInvalidTimeObserverTypeViolation: Bool
        let hasConflictingPlayerInitializer: Bool
        let unsupportedUninitializedProperties: [String]

        var canGenerateMembers: Bool {
            isFinalClass
                && hasMainActorIsolation
                && hasRequiredPlayerProperty
                && !hasInvalidObservedProperty
                && observedTypeMismatches.isEmpty
                && duplicateObservedKeyPaths.isEmpty
                && !hasImmutableTimeObserverViolation
                && !hasMissingTimeObserverIntervalViolation
                && !hasInvalidTimeObserverTypeViolation
                && !hasConflictingPlayerInitializer
                && unsupportedUninitializedProperties.isEmpty
        }
    }

    private static func validationSummary(for classDecl: ClassDeclSyntax) -> ValidationSummary {
        let managedPropertyNames = managedPropertyNames(in: classDecl)
        return ValidationSummary(
            isFinalClass: hasModifier(named: "final", in: classDecl.modifiers),
            hasMainActorIsolation: hasAttribute(named: "MainActor", in: classDecl.attributes),
            hasRequiredPlayerProperty: hasStoredLetProperty(named: "player", typeNamed: "AVPlayer", in: classDecl),
            hasInvalidObservedProperty: hasInvalidObservedProperty(in: classDecl),
            observedTypeMismatches: observedTypeMismatches(in: classDecl),
            duplicateObservedKeyPaths: duplicateObservedKeyPathViolations(in: classDecl),
            hasImmutableTimeObserverViolation: containsImmutableTimeObserverViolation(in: classDecl),
            hasMissingTimeObserverIntervalViolation: containsTimeObserverMissingIntervalViolation(in: classDecl),
            hasInvalidTimeObserverTypeViolation: containsInvalidTimeObserverTypeViolation(in: classDecl),
            hasConflictingPlayerInitializer: hasConflictingInitializer(
                parameterLabel: "player",
                parameterType: "AVPlayer",
                in: classDecl
            ),
            unsupportedUninitializedProperties: unsupportedUninitializedStoredProperties(
                in: classDecl,
                excluding: managedPropertyNames
            )
        )
    }

    static func validateUsage(of declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) -> Bool {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackState can only be applied to a final class.",
                            why: "The macro owns mutable observation lifecycle state that requires stable reference identity.",
                            how: "Apply @PlaybackState to a declaration like '@MainActor final class PlaybackMonitor { let player: AVPlayer }'."
                        ),
                        domain: Self.diagnosticDomain,
                        id: "class-only"
                    )
                )
            )
            return false
        }

        let summary = validationSummary(for: classDecl)

        if !summary.isFinalClass {
            let fixIts = [
                makeAddFinalFixIt(
                    for: classDecl,
                    fixItMessage: MacroFixItMessage("Add 'final' modifier", domain: Self.diagnosticDomain)
                )
            ]

            context.diagnose(
                Diagnostic(
                    node: Syntax(classDecl.name),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackState can only be applied to a final class.",
                            why: "The macro owns mutable observation lifecycle state that requires stable reference identity.",
                            how: "Add the 'final' modifier to this class declaration."
                        ),
                        domain: Self.diagnosticDomain,
                        id: "class-only"
                    ),
                    fixIts: fixIts
                )
            )
        }

        if !summary.hasRequiredPlayerProperty {
            context.diagnose(
                Diagnostic(
                    node: Syntax(classDecl.name),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackState requires a stored instance property 'let player: AVPlayer'.",
                            why: "PlaybackCondition derivation reads AVPlayer surfaces from this property.",
                            how: "Add 'let player: AVPlayer'."
                        ),
                        domain: Self.diagnosticDomain,
                        id: "player-required"
                    )
                )
            )
        }

        if !summary.hasMainActorIsolation {
            let fixIts = [
                makeAddMainActorFixIt(
                    for: classDecl,
                    fixItMessage: MacroFixItMessage("Add '@MainActor' attribute", domain: Self.diagnosticDomain)
                )
            ]

            context.diagnose(
                Diagnostic(
                    node: Syntax(classDecl.name),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackState requires @MainActor isolation.",
                            why: "Observation callbacks mutate derived playback state and must serialize on the main actor.",
                            how: "Annotate the type with '@MainActor'."
                        ),
                        domain: Self.diagnosticDomain,
                        id: "mainactor-required"
                    ),
                    fixIts: fixIts
                )
            )
        }

        if !summary.observedTypeMismatches.isEmpty {
            for mismatch in summary.observedTypeMismatches {
                context.diagnose(
                    Diagnostic(
                        node: mismatch.node,
                        message: MacroDiagnosticMessage(
                            MacroDiagnosticText.compose(
                                what: "@Observed key path '\(mismatch.keyPath)' requires property type '\(mismatch.expectedType)' (found '\(mismatch.actualType)').",
                                why: "PlaybackCondition derivation relies on canonical AVPlayer surface types.",
                                how: "Change the property type to '\(mismatch.expectedType)' for this key path."
                            ),
                            domain: Self.diagnosticDomain,
                            id: "observed-type-mismatch"
                        )
                    )
                )
            }
        }

        if !summary.duplicateObservedKeyPaths.isEmpty {
            for violation in summary.duplicateObservedKeyPaths {
                context.diagnose(
                    Diagnostic(
                        node: violation.node,
                        message: MacroDiagnosticMessage(
                            MacroDiagnosticText.compose(
                                what: "@PlaybackState can observe key path '\(violation.keyPath)' only once.",
                                why: "Duplicate canonical inputs make PlaybackCondition derivation ambiguous.",
                                how: "Remove one duplicated @Observed declaration for '\(violation.keyPath)'."
                            ),
                            domain: Self.diagnosticDomain,
                            id: "observed-duplicate"
                        )
                    )
                )
            }
        }

        if summary.hasConflictingPlayerInitializer {
            context.diagnose(
                Diagnostic(
                    node: Syntax(classDecl.name),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@PlaybackState cannot synthesize 'init(player:)' because it is already declared.",
                            why: "The macro owns this initializer to wire derived state streams and observers.",
                            how: "Remove the custom 'init(player:)' or remove @PlaybackState and manage wiring manually."
                        ),
                        domain: Self.diagnosticDomain,
                        id: "init-conflict"
                    )
                )
            )
        }

        if !summary.unsupportedUninitializedProperties.isEmpty {
            for propertyName in summary.unsupportedUninitializedProperties {
                context.diagnose(
                    Diagnostic(
                        node: Syntax(classDecl.name),
                        message: MacroDiagnosticMessage(
                            MacroDiagnosticText.compose(
                                what: "@PlaybackState cannot synthesize 'init(player:)' because stored property '\(propertyName)' is not initialized.",
                                why: "The synthesized initializer can only assign managed macro properties and 'player'.",
                                how: "Initialize this property inline or provide a custom initializer."
                            ),
                            domain: Self.diagnosticDomain,
                            id: "unsupported-stored-property"
                        )
                    )
                )
            }
        }

        // Some violations are diagnosed by marker macros; generation still must be gated here.
        return summary.canGenerateMembers
    }

    static func canGenerateMembers(for classDecl: ClassDeclSyntax) -> Bool {
        validationSummary(for: classDecl).canGenerateMembers
    }
}
