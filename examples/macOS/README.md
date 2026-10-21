# macOS example

A split view with the controls in the sidebar and the stack over the detail pane. Click and drag a toast to swipe it; hold the mouse button to lift it onto its track. Runs locally without a development team.

Shared controls and sample toasts come from [`../Shared`](../Shared).

## Run

From the repository root, on a Mac with Xcode 16+ and XcodeGen (`brew install xcodegen`):

```sh
scripts/run-example.sh macos
```

That generates `examples/ToastKitExamples.xcodeproj`, builds the `macOSExample` scheme and
launches it. Or by hand:

```sh
cd examples && xcodegen generate && open ToastKitExamples.xcodeproj
```

then choose the `macOSExample` scheme and run.
