# ToastKit examples

One small app for each platform ToastKit supports, built against the package in this
repository, so a change to the kit shows up the next time you run them.

| Folder | Platform | What it shows |
| --- | --- | --- |
| [`iOS`](iOS) | iOS 17+, iPhone and iPad | A tab view, the usual home for toasts: each tab attaches its own stack, which then sits above the tab bar. A second tab draws the same toast in themed glass, `.plain` and a style written from scratch. |
| [`macOS`](macOS) | macOS 14+ | A split view with the controls in the sidebar. Click and drag a toast to swipe it; hold the mouse button down to lift it onto its track. |
| [`watchOS`](watchOS) | watchOS 10+ | The controls as a list, with cards at the screen's full width. |
| [`visionOS`](visionOS) | visionOS 1+ | A split view, plus an ornament below the window that shows a toast. Pinch and drag to swipe; pinch and hold to lift. |
| [`Shared`](Shared) | All four | The sample toasts, the swipe-action sets and the controls every example uses. |

Every example lets you pick:

- **Status:** normal, warning, error or notification.
- **Directions:** left and right (the default), up and down, all four ways, or none.
- **Swipe hints:** whether a swipe shows the actions as it starts (`toastSwipeHints(.immediate)`) or only after a hold.
- **Layout:** bottom or top placement, and the card's width.

Each action you choose is logged under **Recent actions**, through `onToastAction`.

## Running them

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from
[`project.yml`](project.yml), and is not committed:

```sh
brew install xcodegen
cd examples
xcodegen generate
open ToastKitExamples.xcodeproj
```

Pick a scheme (`iOSExample`, `macOSExample`, `watchOSExample` or `visionOSExample`) and a
simulator, then run. To run on a device, choose your development team under **Signing &
Capabilities**; the macOS example runs locally without one.

CI builds all four on every pull request, so they keep up with the package's API.
