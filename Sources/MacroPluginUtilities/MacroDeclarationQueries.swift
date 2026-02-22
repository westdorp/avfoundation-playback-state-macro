import SwiftSyntax

/// Returns whether `modifiers` contains a modifier with the given `name`.
public func hasModifier(named name: String, in modifiers: DeclModifierListSyntax) -> Bool {
    modifiers.contains { modifier in
        modifier.name.text == name
    }
}

/// Returns whether `attributes` contains an attribute with the given `name`.
public func hasAttribute(named name: String, in attributes: AttributeListSyntax) -> Bool {
    attributes.contains { element in
        guard let attribute = element.as(AttributeSyntax.self) else {
            return false
        }

        return attributeNameMatches(attribute, name: name)
    }
}

/// Returns whether `attribute` names `name`, supporting qualified spellings.
public func attributeNameMatches(_ attribute: AttributeSyntax, name: String) -> Bool {
    let attributeName = attribute.attributeName.trimmedDescription
    return attributeName == name || attributeName.hasSuffix(".\(name)")
}

/// Returns whether `type` matches `name`, supporting qualified spellings.
public func typeMatches(_ type: TypeSyntax, name: String) -> Bool {
    let normalized = type.trimmedDescription.filter { character in
        !character.isWhitespace
    }
    return normalized == name || normalized.hasSuffix(".\(name)")
}

/// Returns whether `variableDecl` is an instance property declaration.
public func isInstanceVariable(_ variableDecl: VariableDeclSyntax) -> Bool {
    !variableDecl.modifiers.contains { modifier in
        let name = modifier.name.text
        return name == "static" || name == "class"
    }
}
