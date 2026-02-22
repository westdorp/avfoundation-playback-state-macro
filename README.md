# PlaybackState

`PlaybackState` provides the `@PlaybackState` macro for deriving playback condition state from `AVPlayer` observation inputs.

## What This Package Provides

- `@PlaybackState` macro for generating:
  - a strongly typed `PlaybackCondition` surface,
  - a `playbackCondition` latest value,
  - a `playbackConditions` async stream,
  - observation lifecycle scaffolding.
- `@Observed(...)` marker for typed AVPlayer observation inputs.
- `@TimeObserver(interval: ...)` marker for periodic `CMTime` input.

## Requirements

- Swift 6.2 toolchain.
- Apple platform SDKs at version 26 or newer (macOS/iOS/tvOS/watchOS/visionOS).

## Usage Contract

Apply `@PlaybackState` to a declaration that satisfies all of the following:

- `@MainActor final class`
- Stored `let player: AVPlayer`
- `@Observed(...)` properties use `ObservedKeyPath` cases
- `@TimeObserver(...)` properties are mutable `var CMTime` and provide `interval:`

Supported `ObservedKeyPath` cases:

- `.rate`
- `.timeControlStatus`
- `.reasonForWaitingToPlay`
- `.currentItemStatus`
- `.currentItemIsPlaybackBufferEmpty`
- `.currentItemError`

## Example

```swift
import AVFoundation
import CoreMedia
import PlaybackState

@PlaybackState
@MainActor
final class PlayerObservation {
    let player: AVPlayer

    @Observed(.rate)
    private var rate: Float = 0

    @Observed(.timeControlStatus)
    private var timeControlStatus: AVPlayer.TimeControlStatus = .paused

    @TimeObserver(interval: CMTime(seconds: 0.5, preferredTimescale: 600))
    private var currentTime: CMTime = .zero
}
```

## Package Integration

Once this repo is published, add it as a SwiftPM dependency and depend on product `PlaybackState`.
