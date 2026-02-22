import PlaybackStateMacroPluginUtilities
import SwiftSyntax

/// Extracts `@TimeObserver` interval expressions from attribute syntax.
enum TimeObserverIntervalParser {
    /// Returns the first interval expression found in `attributes`.
    static func intervalExpression(in attributes: AttributeListSyntax) -> String? {
        for element in attributes {
            guard let attribute = element.as(AttributeSyntax.self),
                  let intervalExpression = intervalExpression(in: attribute)
            else {
                continue
            }

            return intervalExpression
        }

        return nil
    }

    /// Returns whether any `@TimeObserver` attribute is missing an interval expression.
    static func hasAttributeMissingInterval(in attributes: AttributeListSyntax) -> Bool {
        attributes.contains { element in
            guard let attribute = element.as(AttributeSyntax.self),
                  attributeNameMatches(attribute, name: "TimeObserver")
            else {
                return false
            }

            return intervalExpression(in: attribute) == nil
        }
    }

    /// Returns the interval expression from `attribute`, supporting labeled and positional forms.
    static func intervalExpression(in attribute: AttributeSyntax) -> String? {
        guard attributeNameMatches(attribute, name: "TimeObserver"),
              let arguments = attribute.arguments?.as(LabeledExprListSyntax.self)
        else {
            return nil
        }

        if let labeledInterval = arguments.first(where: { argument in
            argument.label?.text == "interval"
        }) {
            return labeledInterval.expression.trimmedDescription
        }

        if let first = arguments.first {
            return first.expression.trimmedDescription
        }

        return nil
    }
}
