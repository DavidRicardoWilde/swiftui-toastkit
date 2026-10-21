# Recording the README demos

The GIFs at the top of the README are recorded from the apps in [`examples/`](../examples)
on a Mac. Each lives in `docs/assets/` under the exact name below; the README already
points at them.

## Setup (once)

```sh
brew install xcodegen ffmpeg gifski
```

Use Xcode 16 or later. In the simulator, set light appearance and hide the debug overlays
(**Features ▸ Toggle Appearance**), and set the status-bar time for a clean shot:

```sh
xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100
```

## The clips

| # | Output file | Example / scene | Interaction | Length | GIF width |
| --- | --- | --- | --- | --- | --- |
| 1 | `docs/assets/demo-ios-stack.gif` | iOS, iPhone 16 Pro, **Playground** tab | Tap **Show toast** three times (normal, then warning, then error), so the stack builds; let the front one time out. | 8 s | 360 |
| 2 | `docs/assets/demo-ios-swipe.gif` | iOS, **Playground**, Directions: left and right | Swipe one toast left (delete) and one right (set aside); **Recent actions** logs both. | 8 s | 360 |
| 3 | `docs/assets/demo-ios-hold.gif` | iOS, **Playground**, *Stay until dismissed* on | Press and hold a toast so it lifts onto its track with the actions at the ends, then slide to one. | 6 s | 360 |
| 4 | `docs/assets/demo-ios-styles.gif` | iOS, **Styles** tab | Show the same toast in themed glass, `.plain` and the custom style. | 6 s | 360 |
| 5 | `docs/assets/demo-macos.gif` | macOS example window (960 × 640) | Show two toasts, click-and-drag one away, hold the other. | 8 s | 720 |

Clips 1 to 3 are required for the README's first screen; 4 and 5 are optional (leave their
lines commented out in the README if you skip them).

## Commands

```sh
scripts/run-example.sh ios                 # builds and launches the iOS example
scripts/record-demo.sh ios-stack 8 360     # then perform clip 1
scripts/record-demo.sh ios-swipe 8 360     # clip 2
scripts/record-demo.sh ios-hold 6 360      # clip 3
scripts/record-demo.sh ios-styles 6 360    # clip 4

scripts/run-example.sh macos               # clip 5: record the window with Cmd-Shift-5, then
scripts/record-demo.sh --convert macos ~/Desktop/Screen\ Recording.mov 720
```

Keep each GIF under about 5 MB (lower the width or length if not). Then uncomment the
matching lines in the README's demo block, check it renders, and commit only the `.gif`
files; the `.mov` sources are ignored by git.
