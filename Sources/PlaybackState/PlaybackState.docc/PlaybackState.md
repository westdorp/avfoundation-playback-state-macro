# ``PlaybackState``

Derive one coherent playback condition from multiple `AVPlayer` observation inputs.

## Overview

`@PlaybackState` turns multi-property player observation into a single value-driven interface:

- `playbackCondition`: latest derived condition
- `playbackConditions`: async stream of condition updates

This keeps feature reducers focused on one semantic input instead of coordinating raw AVFoundation callbacks.

## Usage

```swift
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

## Topics

- ``PlaybackState()``
- ``Observed(_:)``
- ``TimeObserver(interval:)``
