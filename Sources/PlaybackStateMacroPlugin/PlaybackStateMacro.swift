import Foundation
import PlaybackStateMacroPluginUtilities
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct PlaybackStateMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard validateUsage(of: declaration, in: context),
              let classDecl = declaration.as(ClassDeclSyntax.self)
        else {
            return []
        }

        let observedProperties = observedProperties(in: classDecl)
        let timeObserverProperties = timeObserverProperties(in: classDecl)

        return [
            DeclSyntax(stringLiteral: buildPlaybackConditionEnumDeclaration()),
            DeclSyntax(stringLiteral: buildPlaybackConditionPropertyDeclaration()),
            DeclSyntax(stringLiteral: buildDerivePlaybackConditionDeclaration(
                observedProperties: observedProperties
            )),
            DeclSyntax(stringLiteral: buildBeginObservationDeclaration(
                observedProperties: observedProperties
            )),
            """
            /// A stream of playback condition changes.
            ///
            /// Each element represents a new condition distinct from the previous one.
            let playbackConditions: AsyncStream<PlaybackCondition>
            """,
            """
            private let _playbackContinuation: AsyncStream<PlaybackCondition>.Continuation
            """,
            """
            private var _timeObserverTokens: [Any] = []
            """,
            DeclSyntax(stringLiteral: buildInitializerDeclaration(
                observedProperties: observedProperties,
                timeObserverProperties: timeObserverProperties
            )),
            """
            /// Tears down time-observer tokens and finishes the playback conditions stream.
            isolated deinit {
                for token in _timeObserverTokens {
                    player.removeTimeObserver(token)
                }
                _playbackContinuation.finish()
            }
            """,
        ]
    }

    public static func expansion(
        of _: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self),
              canGenerateMembers(for: classDecl),
              !hasSendableConformance(in: classDecl, lexicalContext: context.lexicalContext)
        else {
            return []
        }

        return [try ExtensionDeclSyntax("extension \(type): Sendable {}")]
    }
}

public struct ObservedMarkerMacro: PeerMacro {
    /// Validates `@Observed` arguments and emits diagnostics for unsupported key paths.
    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let keyPathCaseName = observedKeyPathCaseName(from: attribute) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(attribute),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@Observed requires an ObservedKeyPath case.",
                            why: "@Observed defines which AVPlayer surfaces feed PlaybackCondition derivation.",
                            how: "Use a supported case such as @Observed(.rate)."
                        ),
                        domain: PlaybackStateMacro.diagnosticDomain,
                        id: "observed-keypath-case"
                    )
                )
            )
            return []
        }

        if ObservedKeyPathRegistry.byCaseName[keyPathCaseName] == nil {
            context.diagnose(
                Diagnostic(
                    node: Syntax(attribute),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "Unrecognized ObservedKeyPath case '.\(keyPathCaseName)'.",
                            why: "@Observed only accepts supported derivation inputs.",
                            how: "Use a supported case such as @Observed(.rate)."
                        ),
                        domain: PlaybackStateMacro.diagnosticDomain,
                        id: "observed-keypath"
                    )
                )
            )
        }
        return []
    }
}

public struct TimeObserverMarkerMacro: PeerMacro {
    /// Validates `@TimeObserver` property requirements and emits targeted diagnostics.
    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            return []
        }

        let isMutableVar = variableDecl.bindingSpecifier.tokenKind == .keyword(.var)
        if !isMutableVar {
            context.diagnose(
                Diagnostic(
                    node: Syntax(attribute),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@TimeObserver requires a mutable 'var CMTime' property.",
                            why: "The macro writes periodic timestamps into this property.",
                            how: "Change 'let' to 'var'."
                        ),
                        domain: PlaybackStateMacro.diagnosticDomain,
                        id: "timeobserver-mutable"
                    )
                )
            )
        }

        let hasCMTimeType = variableDecl.bindings.allSatisfy { binding in
            guard let typeAnnotation = binding.typeAnnotation else {
                return false
            }

            let typeName = typeAnnotation.type.trimmedDescription
            return typeName == "CMTime" || typeName.hasSuffix(".CMTime")
        }

        if !hasCMTimeType {
            context.diagnose(
                Diagnostic(
                    node: Syntax(attribute),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@TimeObserver requires a 'CMTime' property.",
                            why: "Periodic observer updates must store time values.",
                            how: "Change the property type to CMTime."
                        ),
                        domain: PlaybackStateMacro.diagnosticDomain,
                        id: "timeobserver-cmtime"
                    )
                )
            )
        }

        if TimeObserverIntervalParser.intervalExpression(in: attribute) == nil {
            context.diagnose(
                Diagnostic(
                    node: Syntax(attribute),
                    message: MacroDiagnosticMessage(
                        MacroDiagnosticText.compose(
                            what: "@TimeObserver requires an explicit 'interval' argument (for example: @TimeObserver(interval: .seconds(0.5))).",
                            why: "Explicit cadence keeps periodic observation deterministic.",
                            how: "Add an interval argument such as '@TimeObserver(interval: .seconds(0.5))'."
                        ),
                        domain: PlaybackStateMacro.diagnosticDomain,
                        id: "timeobserver-interval"
                    )
                )
            )
        }

        return []
    }
}

extension PlaybackStateMacro {
    static let diagnosticDomain = "PlaybackStateMacro"
}

/// Canonical metadata for a supported `@Observed` AVPlayer key path.
struct ObservedKeyPathDescriptor {
    /// API-facing enum case name accepted by `@Observed`.
    let caseName: String
    /// Canonical key-path spelling used for deduplication.
    let canonicalKeyPath: String
    /// AVPlayer access expression used in generated refresh/derivation code.
    let playerExpression: String
    /// Required Swift type for the annotated property.
    let expectedSwiftType: String
}

enum ObservedKeyPathRegistry {
    static let descriptors: [ObservedKeyPathDescriptor] = [
        ObservedKeyPathDescriptor(
            caseName: "timeControlStatus",
            canonicalKeyPath: "timeControlStatus",
            playerExpression: "player.timeControlStatus",
            expectedSwiftType: "AVPlayer.TimeControlStatus"
        ),
        ObservedKeyPathDescriptor(
            caseName: "rate",
            canonicalKeyPath: "rate",
            playerExpression: "player.rate",
            expectedSwiftType: "Float"
        ),
        ObservedKeyPathDescriptor(
            caseName: "reasonForWaitingToPlay",
            canonicalKeyPath: "reasonForWaitingToPlay",
            playerExpression: "player.reasonForWaitingToPlay",
            expectedSwiftType: "AVPlayer.WaitingReason?"
        ),
        ObservedKeyPathDescriptor(
            caseName: "currentItemStatus",
            canonicalKeyPath: "currentItem.status",
            playerExpression: "player.currentItem?.status",
            expectedSwiftType: "AVPlayerItem.Status?"
        ),
        ObservedKeyPathDescriptor(
            caseName: "currentItemIsPlaybackBufferEmpty",
            canonicalKeyPath: "currentItem.isPlaybackBufferEmpty",
            playerExpression: "player.currentItem?.isPlaybackBufferEmpty",
            expectedSwiftType: "Bool?"
        ),
        ObservedKeyPathDescriptor(
            caseName: "currentItemError",
            canonicalKeyPath: "currentItem.error",
            playerExpression: "player.currentItem?.error",
            expectedSwiftType: "Error?"
        ),
    ]

    static let byCaseName: [String: ObservedKeyPathDescriptor] = {
        var result: [String: ObservedKeyPathDescriptor] = [:]
        for descriptor in descriptors {
            result[descriptor.caseName] = descriptor
        }
        return result
    }()
}
