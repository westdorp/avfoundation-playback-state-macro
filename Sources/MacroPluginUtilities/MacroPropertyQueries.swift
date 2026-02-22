import SwiftSyntax

/// Returns whether `classDecl` declares `let propertyName: typeName` as a stored instance property.
public func hasStoredLetProperty(
    named propertyName: String,
    typeNamed typeName: String,
    in classDecl: ClassDeclSyntax
) -> Bool {
    classDecl.memberBlock.members.contains { member in
        guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
              variableDecl.bindingSpecifier.tokenKind == .keyword(.let),
              isInstanceVariable(variableDecl)
        else {
            return false
        }

        return variableDecl.bindings.contains { binding in
            guard binding.accessorBlock == nil,
                  let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  identifierPattern.identifier.text == propertyName,
                  let typeAnnotation = binding.typeAnnotation
            else {
                return false
            }

            let type = typeAnnotation.type.trimmedDescription
            return type == typeName || type.hasSuffix(".\(typeName)")
        }
    }
}

/// Returns names of stored instance properties without initializers that are not macro-managed.
public func unsupportedUninitializedStoredProperties(
    in classDecl: ClassDeclSyntax,
    excluding managedPropertyNames: Set<String>
) -> [String] {
    // Validation runs against the source declaration before member synthesis.
    // Macro-generated members are intentionally excluded from this check.
    classDecl.memberBlock.members.flatMap { member -> [String] in
        guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
              isInstanceVariable(variableDecl)
        else {
            return []
        }

        return variableDecl.bindings.compactMap { binding in
            guard binding.accessorBlock == nil,
                  binding.initializer == nil,
                  let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
            else {
                return nil
            }

            let propertyName = identifierPattern.identifier.text
            return managedPropertyNames.contains(propertyName) ? nil : propertyName
        }
    }
}

/// Returns whether `classDecl` declares `init(parameterLabel: parameterType)`.
public func hasConflictingInitializer(
    parameterLabel: String,
    parameterType: String,
    in classDecl: ClassDeclSyntax
) -> Bool {
    classDecl.memberBlock.members.contains { member in
        guard let initializerDecl = member.decl.as(InitializerDeclSyntax.self) else {
            return false
        }

        let parameters = initializerDecl.signature.parameterClause.parameters
        guard parameters.count == 1, let parameter = parameters.first else {
            return false
        }

        let hasExpectedLabel = parameter.firstName.text == parameterLabel
        let hasExpectedType = typeMatches(parameter.type, name: parameterType)
        return hasExpectedLabel && hasExpectedType
    }
}
