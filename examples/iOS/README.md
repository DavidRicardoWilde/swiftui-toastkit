# iOS example

A tab view: **Playground** holds the controls and its own toast stack above the tab bar; **Styles** draws one toast in themed glass, `.plain` and a custom `ToastStyle`. Runs on iPhone and iPad simulators.

Shared controls and sample toasts come from [`../Shared`](../Shared).

## Run

From the repository root, on a Mac with Xcode 16+ and XcodeGen (`brew install xcodegen`):

```sh
scripts/run-example.sh ios
```

That generates `examples/ToastKitExamples.xcodeproj`, builds the `iOSExample` scheme and
launches it on a simulator (pass a simulator name as a second argument to pick another). Or by hand:

```sh
cd examples && xcodegen generate && open ToastKitExamples.xcodeproj
```

then choose the `iOSExample` scheme and run.
