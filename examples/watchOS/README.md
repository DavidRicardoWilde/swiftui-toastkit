# watchOS example

The controls as a list, with cards at the screen's full width.

Shared controls and sample toasts come from [`../Shared`](../Shared).

## Run

From the repository root, on a Mac with Xcode 16+ and XcodeGen (`brew install xcodegen`):

```sh
scripts/run-example.sh watchos
```

That generates `examples/ToastKitExamples.xcodeproj`, builds the `watchOSExample` scheme and
launches it on a simulator (pass a simulator name as a second argument to pick another). Or by hand:

```sh
cd examples && xcodegen generate && open ToastKitExamples.xcodeproj
```

then choose the `watchOSExample` scheme and run.
