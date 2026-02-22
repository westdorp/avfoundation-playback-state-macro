import Foundation
import PlaybackStateMacroPluginUtilities
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

extension PlaybackStateMacro {
    /// Returns recognized `@Observed` properties that can participate in generation.
    static func observedProperties(in classDecl: ClassDeclSyntax) -> [ObservedProperty] {
        classDecl.memberBlock.members.flatMap { member -> [ObservedProperty] in
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
                  isInstanceVariable(variableDecl),
                  let keyPathCaseName = observedKeyPath(in: variableDecl.attributes),
                  let descriptor = ObservedKeyPathRegistry.byCaseName[keyPathCaseName]
            else {
                return []
            }

            return variableDecl.bindings.compactMap { binding in
                guard binding.accessorBlock == nil,
                      let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
                else {
                    return nil
                }

                return ObservedProperty(
                    name: identifierPattern.identifier.text,
                    keyPath: descriptor.canonicalKeyPath,
                    sourceExpression: descriptor.playerExpression
                )
            }
        }
    }

    /// Returns valid `@TimeObserver` properties with extracted interval expressions.
    static func timeObserverProperties(in classDecl: ClassDeclSyntax) -> [TimeObserverProperty] {
        classDecl.memberBlock.members.flatMap { member -> [TimeObserverProperty] in
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
                  isInstanceVariable(variableDecl),
                  let intervalExpression = timeObserverIntervalExpression(in: variableDecl.attributes)
            else {
                return []
            }

            return variableDecl.bindings.compactMap { binding in
                guard binding.accessorBlock == nil,
                      let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self),
                      let typeAnnotation = binding.typeAnnotation,
                      typeMatchesCMTime(typeAnnotation.type)
                else {
                    return nil
                }

                return TimeObserverProperty(
                    name: identifierPattern.identifier.text,
                    intervalExpression: intervalExpression
                )
            }
        }
    }

    /// Returns names managed by the macro's synthesized `init(player:)`.
    static func managedPropertyNames(in classDecl: ClassDeclSyntax) -> Set<String> {
        let observed = observedDeclaredPropertyNames(in: classDecl)
        let timeObserved = timeObserverDeclaredPropertyNames(in: classDecl)
        return Set(["player"] + observed + timeObserved)
    }

    /// Returns all properties declared with `@Observed`, regardless of key-path validity.
    static func observedDeclaredPropertyNames(in classDecl: ClassDeclSyntax) -> [String] {
        classDecl.memberBlock.members.flatMap { member -> [String] in
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
                  isInstanceVariable(variableDecl),
                  hasObservedAttribute(in: variableDecl.attributes)
            else {
                return []
            }

            return variableDecl.bindings.compactMap { binding in
                guard binding.accessorBlock == nil,
                      let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
                else {
                    return nil
                }

                return identifierPattern.identifier.text
            }
        }
    }

    /// Returns all properties declared with `@TimeObserver`, regardless of argument validity.
    static func timeObserverDeclaredPropertyNames(in classDecl: ClassDeclSyntax) -> [String] {
        classDecl.memberBlock.members.flatMap { member -> [String] in
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
                  isInstanceVariable(variableDecl),
                  hasTimeObserverAttribute(in: variableDecl.attributes)
            else {
                return []
            }

            return variableDecl.bindings.compactMap { binding in
                guard binding.accessorBlock == nil,
                      let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
                else {
                    return nil
                }

                return identifierPattern.identifier.text
            }
        }
    }

    /// Returns whether any `@TimeObserver` property violates the mutable `var` requirement.
    static func containsImmutableTimeObserverViolation(in classDecl: ClassDeclSyntax) -> Bool {
        classDecl.memberBlock.members.contains { member in
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
                  hasTimeObserverAttribute(in: variableDecl.attributes)
            else {
                return false
            }

            return variableDecl.bindingSpecifier.tokenKind != .keyword(.var)
        }
    }

    /// Returns whether any `@TimeObserver` attribute omits the required interval argument.
    static func containsTimeObserverMissingIntervalViolation(in classDecl: ClassDeclSyntax) -> Bool {
        classDecl.memberBlock.members.contains { member in
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
                  hasTimeObserverAttribute(in: variableDecl.attributes)
            else {
                return false
            }

            return TimeObserverIntervalParser.hasAttributeMissingInterval(in: variableDecl.attributes)
        }
    }

    /// Returns whether any `@TimeObserver` property violates the required `CMTime` type.
    static func containsInvalidTimeObserverTypeViolation(in classDecl: ClassDeclSyntax) -> Bool {
        classDecl.memberBlock.members.contains { member in
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
                  hasTimeObserverAttribute(in: variableDecl.attributes)
            else {
                return false
            }

            return variableDecl.bindings.contains { binding in
                guard binding.accessorBlock == nil,
                      let typeAnnotation = binding.typeAnnotation
                else {
                    return false
                }

                return !typeMatchesCMTime(typeAnnotation.type)
            }
        }
    }

    /// Returns whether any `@Observed` declaration uses an unsupported key-path argument.
    static func hasInvalidObservedProperty(in classDecl: ClassDeclSyntax) -> Bool {
        classDecl.memberBlock.members.contains { member in
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
                return false
            }

            return variableDecl.attributes.contains { element in
                guard let attribute = element.as(AttributeSyntax.self),
                      attributeNameMatches(attribute, name: "Observed")
                else {
                    return false
                }

                guard let keyPath = ObservedMarkerMacro.observedKeyPathCaseName(from: attribute) else {
                    return true
                }

                return ObservedKeyPathRegistry.byCaseName[keyPath] == nil
            }
        }
    }

    /// Returns duplicate canonical observed key paths, anchored to duplicate property identifiers.
    static func duplicateObservedKeyPathViolations(in classDecl: ClassDeclSyntax) -> [ObservedDuplicateKeyPath] {
        var seenCanonicalKeyPaths: Set<String> = []
        var duplicates: [ObservedDuplicateKeyPath] = []

        for member in classDecl.memberBlock.members {
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
                  isInstanceVariable(variableDecl),
                  let keyPathCaseName = observedKeyPath(in: variableDecl.attributes),
                  let descriptor = ObservedKeyPathRegistry.byCaseName[keyPathCaseName]
            else {
                continue
            }

            let canonicalKeyPath = descriptor.canonicalKeyPath
            for binding in variableDecl.bindings {
                guard binding.accessorBlock == nil,
                      let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
                else {
                    continue
                }

                if seenCanonicalKeyPaths.contains(canonicalKeyPath) {
                    duplicates.append(
                        ObservedDuplicateKeyPath(
                            node: Syntax(identifierPattern.identifier),
                            keyPath: canonicalKeyPath
                        )
                    )
                } else {
                    seenCanonicalKeyPaths.insert(canonicalKeyPath)
                }
            }
        }

        return duplicates
    }

    /// Returns observed properties whose declared type disagrees with key-path expectations.
    static func observedTypeMismatches(in classDecl: ClassDeclSyntax) -> [ObservedTypeMismatch] {
        classDecl.memberBlock.members.flatMap { member -> [ObservedTypeMismatch] in
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
                  isInstanceVariable(variableDecl),
                  let keyPathCaseName = observedKeyPath(in: variableDecl.attributes),
                  let descriptor = ObservedKeyPathRegistry.byCaseName[keyPathCaseName]
            else {
                return []
            }

            return variableDecl.bindings.compactMap { binding -> ObservedTypeMismatch? in
                guard binding.accessorBlock == nil,
                      let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self),
                      let typeAnnotation = binding.typeAnnotation,
                      !typeMatches(typeAnnotation.type, name: descriptor.expectedSwiftType)
                else {
                    return nil
                }

                return ObservedTypeMismatch(
                    node: Syntax(identifierPattern.identifier),
                    keyPath: descriptor.canonicalKeyPath,
                    expectedType: descriptor.expectedSwiftType,
                    actualType: typeAnnotation.type.trimmedDescription
                )
            }
        }
    }

    /// Returns the first `@Observed` key-path argument from `attributes`.
    static func observedKeyPath(in attributes: AttributeListSyntax) -> String? {
        attributes.lazy.compactMap { element -> String? in
            guard let attribute = element.as(AttributeSyntax.self),
                  attributeNameMatches(attribute, name: "Observed")
            else {
                return nil
            }
            return ObservedMarkerMacro.observedKeyPathCaseName(from: attribute)
        }.first
    }

    /// Returns the first parsed time-observer interval expression from `attributes`.
    static func timeObserverIntervalExpression(in attributes: AttributeListSyntax) -> String? {
        TimeObserverIntervalParser.intervalExpression(in: attributes)
    }

    /// Returns whether `attributes` includes `@TimeObserver`.
    static func hasTimeObserverAttribute(in attributes: AttributeListSyntax) -> Bool {
        attributes.contains { element in
            guard let attribute = element.as(AttributeSyntax.self) else {
                return false
            }

            return attributeNameMatches(attribute, name: "TimeObserver")
        }
    }

    /// Returns whether `attributes` includes `@Observed`.
    static func hasObservedAttribute(in attributes: AttributeListSyntax) -> Bool {
        attributes.contains { element in
            guard let attribute = element.as(AttributeSyntax.self) else {
                return false
            }

            return attributeNameMatches(attribute, name: "Observed")
        }
    }

    static func typeMatchesCMTime(_ type: TypeSyntax) -> Bool {
        typeMatches(type, name: "CMTime")
    }
}
