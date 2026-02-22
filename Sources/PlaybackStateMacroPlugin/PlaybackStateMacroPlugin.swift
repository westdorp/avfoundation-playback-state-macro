import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PlaybackStateMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PlaybackStateMacro.self,
        ObservedMarkerMacro.self,
        TimeObserverMarkerMacro.self,
    ]
}
