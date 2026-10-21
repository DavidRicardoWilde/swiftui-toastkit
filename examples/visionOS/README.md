# visionOS example

A split view plus an ornament below the window that shows a toast. Pinch and drag to swipe; pinch and hold to lift.

Shared controls and sample toasts come from [`../Shared`](../Shared).

## Run

From the repository root, on a Mac with Xcode 16+ and XcodeGen (`brew install xcodegen`):

```sh
scripts/run-example.sh visionos
```

That generates `examples/ToastKitExamples.xcodeproj`, builds the `visionOSExample` scheme and
launches it on a simulator (pass a simulator name as a second argument to pick another). Or by hand:

```sh
cd examples && xcodegen generate && open ToastKitExamples.xcodeproj
```

then choose the `visionOSExample` scheme and run.
