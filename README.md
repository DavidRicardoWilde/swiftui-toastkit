# ToastKit

Stacked, swipeable toast notifications for SwiftUI.

ToastKit separates what a toast *does* from how it *looks*. The views handle stacking,
timing, gestures and accessibility, and draw nothing of their own. Every card is drawn by
a `ToastStyle`: the frosted-glass default, the bare `.plain` style, or your own.

- **A stack, not a queue.** The newest toast sits in front. Older ones peek out behind it
  and come forward as the front one leaves.
- **Tap, swipe either way, or press and hold.** Each gesture runs an action you define. By
  default, swiping toward the leading side deletes a toast. Swiping toward the trailing
  side sets it aside until the page is next opened.
- **Actions you can read before choosing.** Pressing and holding lifts the card onto a
  curved track with both swipe actions laid out at its ends: icon, title and subtitle.
- **Timing that waits for the user.** Only the front toast counts down. The countdown
  pauses while a finger is on the stack or the app is in the background.
- **Progress that stays up.** A progress toast shows a bar while work runs, can offer
  Cancel, and turns into its result in place when the work ends.
- **Bottom by default, clear of whatever is there.** The stack sits above system tab bars
  and their accessories in any placement. Mark anything else, such as a custom tab bar, and
  the stack lifts itself clear of it.
- **Unstyled core, styled default.** Restyle with a token theme or replace the drawing
  outright with a `ToastStyle`.
- **Accessible.** VoiceOver offers every action by name. Reduce Motion, Reduce
  Transparency and Increase Contrast are honoured, and Dynamic Type scales the card.

iOS 17+, macOS 14+, watchOS 10+, visionOS 1+. Swift 5.10+. No dependencies beyond SwiftUI.

## Contents

- [Documentation website](#documentation-website)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Running the example](#running-the-example)
- [Presenting toasts](#presenting-toasts)
- [Dismissing toasts](#dismissing-toasts)
- [How long a toast stays](#how-long-a-toast-stays)
- [Progress toasts](#progress-toasts)
- [Actions: tap, swipe, press and hold](#actions-tap-swipe-press-and-hold)
- [Styling](#styling)
- [Placement](#placement)
- [Sizing](#sizing)
- [Accessibility](#accessibility)
- [Platforms and localization](#platforms-and-localization)
- [Testing your code](#testing-your-code)
- [Architecture](#architecture)
- [Roadmap](#roadmap)
- [License](#license)

## Documentation website

Live docs: [toastkit.studio.gluttongk.com](https://toastkit.studio.gluttongk.com) (English, Simplified and Traditional Chinese, Japanese, Korean, and Spanish).

To run the Astro site locally from `docs/`:

```sh
cd docs
npm install
npm run dev
```

English is served at `/`, with localized pages at `/zh-cn/`, `/zh-hant/`, `/ja/`, `/ko/`, and `/es/`. Run `npm run build` to type-check and generate the static site in `docs/dist/`.

## Installation

Add the package with Swift Package Manager and depend on the `ToastKit` product:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/DavidRicardoWilde/swiftui-toastkit.git", .upToNextMinor(from: "0.1.0"))
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [.product(name: "ToastKit", package: "swiftui-toastkit")]
    )
]
```

In Xcode, use **File › Add Package Dependencies…**, enter
`https://github.com/DavidRicardoWilde/swiftui-toastkit`, and add the `ToastKit` library to
your app target.

Releases follow [semantic versioning](https://semver.org). Before 1.0, a minor release may
change the API, so `.upToNextMinor(from:)` is the safe requirement; patch releases only fix.

## Quick start

Keep a `ToastCenter` in state, attach it to a view with `.toasts(_:)`, and present.

```swift
import SwiftUI
import ToastKit

struct ContentView: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        Button("Save") {
            toasts.present(.normal, title: "Saved")
        }
        .toasts(toasts)
    }
}
```

The toast appears at the bottom of the safe area, stays four seconds, and can be swiped
away. Swipe left to delete it, or right to bring it back the next time the view appears.

## Running the example

The repository includes a small demo app at `Examples/ToastKitDemo`. It is a
regular Xcode project, so there is nothing to generate first. It needs Xcode 16
or later, with the platforms you want to try installed under
**Settings > Components**.

1. Open `Examples/ToastKitDemo/ToastKitDemo.xcodeproj`.
2. Choose a scheme and a run destination:
   - **ToastKitDemo** runs on an iPhone or iPad simulator, on **My Mac**, or on
     an Apple Vision Pro simulator. It is one multiplatform target, so all
     three appear in the same destination menu.
   - **ToastKitDemoWatch** is a standalone Apple Watch app. Pick an Apple Watch
     simulator.
3. Press Run.

Both targets depend on this checkout of ToastKit through a local package
reference (`../..`), so any change you make to the library shows up in the
demo on the next build. The bundle identifiers are the placeholders
`com.example.ToastKitDemo` and `com.example.ToastKitDemo.watchkitapp`.
Simulators and My Mac need no signing setup. To run on a physical device,
choose your own team under **Signing & Capabilities** and change the bundle
identifiers to ones you own.

The watch app is a compact version of the playground: each status, a short
stack, swipe actions, a tap action and top or bottom placement. It is one list, with
three more sections:

- **Sizes** switches between the compact, regular and large sizes. Every size is the
  full width on the watch.
- **Dismiss** removes the front toast, the "upload" group or everything, with a trail
  and a choice of direction.
- **Progress** runs a workout-sync style flow: an indeterminate "Connecting…", then a
  determinate bar, with Cancel and a success haptic. The compact size shows the
  percentage only.

On iPhone, iPad, Mac and Apple Vision Pro, the demo has five tabs:

- **Playground** shows each status, a burst of stacked toasts, a persistent
  toast, tap actions, swipe actions on both sides, press and hold, postponed
  toasts, and top or bottom placement. A switch makes the custom tab bar
  taller, so you can watch toasts move to stay clear of it.
- **Styles** switches between the glass style, `.plain` and a custom
  `ToastStyle`, and between the standard theme and a custom `ToastTheme`
  built with `statusTint`, and between the compact, regular and large sizes.
- **Sizes** shows the three sizes side by side, each in its own pane, and lets you
  pin an explicit width to see that it beats the size's. On iPhone a picker changes
  Dynamic Type, on Mac the panes are 280 and 480 pt and follow the window, and on
  Apple Vision Pro they use fractional widths.
- **Dismissal** has one section for each way out: a single toast, a group ("Uploads
  ×3"), the toasts that match a test, and everything, with a picker for the scope,
  postponed toasts included. Fade, slide and trail combine with every direction.
- **Progress** uploads a photo with byte counts, uploads a video whose Cancel cancels
  the Task, fails and retries on the same card, runs a burst of six to show running
  cards being hidden, and hides a card that then fails and comes back. Switches turn
  on the swipe that cancels and the second tap before Cancel. On Mac it copies a
  folder through a Foundation `Progress`, and on Apple Vision Pro an indeterminate
  "Preparing…" turns determinate.

## Presenting toasts

A toast is a `ToastMessage`: what it says, how long it stays, and what tapping or swiping
it does.

```swift
toasts.present(.warning, title: "Low storage", message: "Free up space to keep syncing.")

toasts.present(ToastMessage(
    status: .notification,
    title: "New photos",
    message: "12 photos from today",
    icon: .system("photo.on.rectangle"),
    duration: 6,
    tapAction: ToastAction(title: "View") { _ in open() }
))
```

| Property | Default | Meaning |
| --- | --- | --- |
| `id` | a new `UUID` | Identity within the stack. Presenting an id that is already showing refreshes that card instead of adding a second one. |
| `status` | `.normal` | `.normal`, `.warning`, `.error` or `.notification`. The default style takes its colours and glyph from the status, and the arrival haptic too. |
| `title` | — | The first line. |
| `message` | `nil` | An optional second line. The default style clamps it to two lines. |
| `icon` | `nil` | A `ToastIcon` that replaces the status glyph: `.system("name")` for an SF Symbol, `.asset("name", bundle:)` for an asset catalog image. |
| `duration` | `.automatic` | See [How long a toast stays](#how-long-a-toast-stays). |
| `tapAction` | `nil` | What a tap does. See [Actions](#actions-tap-swipe-press-and-hold). |
| `swipeActions` | `.standard` | What swiping each way does: delete one way, later the other. |
| `group` | `nil` | A `ToastGroup` of your choosing, such as `"upload"`, to dismiss related toasts together. See [Dismissing toasts](#dismissing-toasts). |

Re-presenting an id updates a toast in place, which suits a status that changes. For
work that has a progress bar, can be cancelled or can fail, see
[Progress toasts](#progress-toasts).

```swift
let syncID = UUID()
toasts.present(ToastMessage(id: syncID, title: "Syncing 3 items…", duration: .indefinite))
// later
toasts.present(ToastMessage(id: syncID, title: "Synced"))
```

Remove toasts from code with `dismiss(id:)`, `dismissTopmost()` or `dismissAll()`, or
several at once: see [Dismissing toasts](#dismissing-toasts).

### The stack

The newest toast is drawn in front; up to `visibleDepth` (3) cards show, and older ones
recede behind it, slightly smaller and dimmer. Only the front card takes touches. Past
`capacity` (5) the oldest *timed* toasts are dropped first, so a toast the user has to
acknowledge (`duration: .indefinite`) survives a burst of routine ones.

```swift
let toasts = ToastCenter(visibleDepth: 2, capacity: 8)
```

## Dismissing toasts

One toast at a time, with `dismiss(id:)` or `dismissTopmost()`:

```swift
let savedID = UUID()
toasts.present(ToastMessage(id: savedID, title: "Saved"))

toasts.dismiss(id: savedID)     // this one, showing or postponed
toasts.dismissTopmost()         // whichever is in front
```

Several at once, give related toasts a **group**, or match them with a closure:

```swift
toasts.present(.normal, title: "Uploading photo 1 of 3", group: "upload")
toasts.present(ToastMessage(title: "Uploading photo 2 of 3", group: "upload"))

toasts.dismiss(group: "upload")                                     // every toast in the group
toasts.dismiss(group: "upload", removal: .slide(.trailing))         // the same, leaving by sliding
toasts.dismiss(removal: .trail()) { $0.status == .error }           // every toast the closure accepts
toasts.dismissAll(removal: .trail(), scope: .everywhere)            // the whole stack, postponed included
```

A group is a name you choose, `"sync"` or `"upload:\(id)"`. Presenting a toast never
replaces another in the same group, and a toast without a group never matches
`dismiss(group:)`. Each call returns how many toasts it removed, postponed ones included,
and a batch is one change: the countdown is reconciled once, and a toast beneath is timed
from the moment the batch lands. It never waits for an animation.

`group:` is a required parameter of its own `ToastMessage.init` and `present` overloads,
so the original ones are unchanged.

### Scope

| `scope` | Reaches | Default for |
| --- | --- | --- |
| `.onScreen` | Toasts in the stack | `dismissAll()`, `dismissAll(removal:scope:)` |
| `.postponed` | Toasts waiting in `postponed` | |
| `.everywhere` | Both | `dismiss(id:)`, `dismiss(group:)`, `dismiss(where:)` |

### Removal styles

`removal:` chooses how the cards leave; `nil`, the default, uses the stack's own setting.

| `removal` | The card |
| --- | --- |
| `.fade` | Dissolves where it stands. The default, and what every removal used to look like. |
| `.slide(direction)` | Slides off while fading, all cards together. |
| `.trail(direction)` | Winds up slightly, then leaves shrinking and blurring, front card first and the others a beat behind. Three cards take about 0.43 s; no batch takes more than 0.6 s. |

Both take a direction, `.towardAnchor` by default:

| `direction` | Travels |
| --- | --- |
| `.inPlace` | Not at all |
| `.towardAnchor`, `.awayFromAnchor` | Toward or away from the edge the stack hangs from |
| `.top`, `.bottom` | Up or down the screen |
| `.leading`, `.trailing` | To the layout direction's start or end; they flip in right-to-left layouts |
| `.degrees(_:)` | 0° is right and angles grow clockwise, so 90° is down and −90° is up. Never mirrored |
| `.vector(dx:dy:)` | Along the vector, in screen space where y grows downward. Never mirrored |

Cards travel far enough to leave the region the stack was given.

```swift
toasts.dismiss(group: "upload", removal: .trail(.degrees(-90)))   // wind up, then leave upward
toasts.dismissAll(removal: .slide(.awayFromAnchor))               // away from the edge the stack hangs from
```

`.toastRemoval(_:)` sets the default for removals that do not choose one, which covers a
toast that expires, one dropped for capacity, `dismiss(id:)` and `dismissAll()`:

```swift
ContentView()
    .toasts(toasts)
    .toastRemoval(.trail())
```

A card the user swipes away, or one they choose an action for, keeps its own exit. A card
held on its action track when code removes it leaves at once and its hold is cancelled.
With Reduce Motion, every removal is a cross-fade and all cards fade together.

A stack should be shown by one view per center: two stacks drawing the same center would
both draw an exit. Do not reference the dismiss methods bare (`let f = toasts.dismiss`);
with the overloads, that needs a type annotation. Calls and full names such as
`dismiss(id:)` are fine.

### Progress toasts are hidden, not cancelled

Dismissing never stops work. Every call above hides a running [progress toast](#progress-toasts)
instead of removing it: the card leaves the stack, `handle.isVisible` turns `false`, and
the work carries on. Hidden cards count in the number a call returns and in the VoiceOver
announcement, but no `scope` reaches them, because a hidden card is neither on screen nor
postponed. Swiping a running card hides it too, and so does `.later`.

To stop the work, cancel it. `cancelProgress(group:)` cancels every running card in a
group, hidden ones included, and returns how many it asked. To make swiping cancel as
well, opt in:

```swift
toasts.cancelProgress(group: "upload")

var options = ToastProgressOptions()
options.swipeActions = ToastSwipeActions(leading: .cancelProgress, trailing: .hideProgress)
```

Capacity follows the same rule. Past `capacity`, the oldest *timed* toasts go first,
finished progress cards among them. Next the oldest running cards are hidden, which loses
nothing: the work continues, and a failure brings the card back. Only then are ordinary
persistent toasts dropped.

## How long a toast stays

```swift
ToastMessage(title: "Saved")                               // .automatic — the center's default
ToastMessage(title: "Copied", duration: 2)                 // two seconds
ToastMessage(title: "Sync failed", duration: .indefinite)  // until the user acts on it
```

`.automatic` uses the center's `defaultDuration`, four seconds unless you choose another:

```swift
let toasts = ToastCenter(defaultDuration: 6)
```

A duration counts time *seen in front*, not time since presenting:

1. Only the front toast counts down. Presenting a new toast moves the countdown onto it;
   the one it covers keeps its whole duration for later.
2. When the front toast leaves, the one beneath starts its own full countdown.
3. The countdown pauses while a finger is on the stack and while the app is in the
   background, then resumes with the time that was left.

`duration: 0` still means "until dismissed", as it did before `.indefinite` existed.

## Progress toasts

Work that takes a while, such as an upload, an export or a sync, needs a toast that stays
up, shows how far it has got, and turns into its result where it stands. A progress toast
is that. It is never timed while the work runs. It can draw a bar, offer Cancel, and
survive being swiped away. When the work ends, the same card becomes a success or a
failure, keeping its place in the stack.

### Values

`ToastProgress` says how far the work has got. It is a plain `Sendable` value, so any
thread can build one:

```swift
handle.update(.indeterminate)                       // a sweeping bar, no number
handle.update(.fraction(0.4))                       // 40%
handle.update(.fraction(0.4, subtitle: "Resizing")) // your own detail line
handle.update(.bytes(12_000_000, of: 30_000_000))   // "12 MB of 30 MB"
handle.update(.items(3, of: 10))                    // "3 of 10"
handle.update(fraction: nil)                        // back to indeterminate
```

A fraction is clamped to 0…1. `.bytes` and `.items` work the fraction out from the counts,
or stay indeterminate when the total is `nil`, and write the detail line in the user's
locale. A `subtitle` replaces the generated line.

### The handle

`track(title:)` presents the card and returns a `ToastProgressHandle`. Report on the work
through it, then finish with exactly one outcome:

```swift
let handle = toasts.track(title: "Syncing", group: "sync")   // indeterminate; never times out
handle.update(.items(3, of: 10))                             // "3 of 10"
handle.update(fraction: 0.8)
handle.succeed(ToastProgressResult(title: "Synced", message: "10 items"))
```

`track` also takes `message`, `icon`, a starting `progress`, `options` and `onCancel`.
The handle lives on the main actor, and `phase`, `isCancellationRequested` and
`isVisible` can be observed. Calls after the first outcome are ignored, as are calls
from a handle of an earlier run of the same id.

**Keep the handle until the work ends.** A handle released without an outcome is
abandoned: the work is cancelled through its cancel route, if it has one, the card is
removed, and a debug build prints a warning.

`update(title:message:)` rewords the card while the work goes on, which suits a state
such as "Waiting for network…". Pass `.some(nil)` as the message to remove that line:

```swift
handle.update(title: "Waiting for network…")                   // reword; the bar stays
handle.update(message: "Will resume when you're back online")
handle.update(title: "Uploading video", message: .some(nil))   // back again, second line removed
```

ToastKit does not detect stalled work. If you know the work is waiting, say so this way.

### `withProgress`

From async code, `withProgress` runs the work and looks after the card. The example is an
iOS and macOS upload; the API is the same on every platform:

```swift
let url = try await toasts.withProgress(
    title: "Uploading video",
    group: "upload",
    operation: { report in
        try await uploader.upload(file) { sent, total in report(.bytes(sent, of: total)) }
    }
)
```

`withProgress` returns what the operation returns and rethrows what it throws. The
`report` value is `Sendable`, so call it from any thread. Updates coalesce, so only the
latest value of a burst reaches the card, and reporting often costs the main actor next to
nothing. Besides `report(_:)` and `report(fraction:)`, it has `update(title:message:)`
and `follow(_:)`, which adopts a Foundation `Progress` such as `URLSessionTask.progress`.

The operation runs off the main actor in a task of its own, so capture only `Sendable`
values. How it ends decides the card:

| The operation | The card |
| --- | --- |
| returns | Succeeds, using `success:` to build the result from the value. |
| throws `CancellationError`, or throws after a cancel | Cancels. |
| throws anything else | Fails, using `failure:` to build the result from the error, and rethrows. |

### Tracking a `Progress`

Foundation's `Progress` can drive a card directly, which suits `URLSessionTask`:

```swift
// .automatic, the default: the card succeeds when the Progress finishes, so the handle can go.
toasts.track(task.progress, title: "Downloading", group: "download")

// .manual: the outcome is yours, for example once the server has answered.
let handle = toasts.track(task.progress, title: "Uploading", completion: .manual)
handle.succeed(ToastProgressResult(title: "Uploaded"))
```

The fraction comes from `fractionCompleted`, and the counts from `completedUnitCount` and
`totalUnitCount`: bytes when `kind` is `.file`, items otherwise. Cancel is offered when
`isCancellable` and calls `progress.cancel()`. With `.automatic` the kit watches the
`Progress` itself and the handle may be dropped. With `.manual` the handle is yours to
keep, and the abandonment rule above applies. Use it when the server replies after the
last byte is sent.

To show several uploads as one card, give them a parent `Progress` and track that:

```swift
let batch = Progress(totalUnitCount: Int64(photos.count))
toasts.track(batch, title: "Uploading \(photos.count) photos", group: "upload")
for photo in photos {
    batch.addChild(photo, withPendingUnitCount: 1)
}
```

### Completion and retry

The card changes where it stands. It keeps its id and its place, and nothing moves to the
front or restarts a countdown.

| | Success | Failure |
| --- | --- | --- |
| Title | "Done", or `result.title` | "Couldn't finish", or `result.title` |
| Status | Unchanged | `.error` |
| Icon | A checkmark, or `result.icon` | The error glyph, or `result.icon` |
| Buttons | None | **Retry**, when there is something to run |
| Stays | `successDuration`: `.automatic` | `failureDuration`: 8 seconds |
| Swipe actions | `.standard` | `.standard` |
| Haptic | The theme's `.normal` | The theme's `.error` |

A finished card is an ordinary timed toast. It starts counting down once it is in front,
or waits its turn if it is buried, so a result is never lost. There is no haptic on
visionOS.

Retry reuses the card. Give `fail` a closure, and start the work again with the same `id`:

```swift
func send(_ toasts: ToastCenter, id: UUID = UUID()) {
    let handle = toasts.track(id: id, title: "Sending", onCancel: { /* stop the request */ })
    Task {
        do {
            try await client.send(progress: { handle.update(fraction: $0) })
            handle.succeed()
        } catch {
            handle.fail(ToastProgressResult(message: "No connection")) {
                send(toasts, id: id)     // the same id: the card resumes in place
            }
        }
    }
}
```

Tapping Retry runs the closure, then removes the card unless the same id was tracked again.
Start the new run **synchronously**, or in a `Task` created inside the closure, as above;
a run started later finds the card gone. `withProgress` takes the same `onRetry:` closure.

### Cancellation

The card shows a Cancel button while the work runs and a way to stop it exists: an
`onCancel` closure, `handle.cancels(_:)`, a cancellable `Progress`, or
`withProgress(cancellable: true)`, the default. Pressing it moves the card to
`.cancelling`: the button dims, the detail line reads "Cancelling…" and the bar goes
indeterminate. Then the work is asked to stop:

```swift
// Cancel cancels the Task, and the card finishes when the Task ends.
let handle = toasts.track(title: "Uploading video", group: "upload")
handle.cancels(upload)

// From code: one card, or every running card in a group.
handle.cancel()
toasts.cancelProgress(group: "upload")

// Cancelling the Task that awaits withProgress cancels its operation too.
let job = Task {
    try await toasts.withProgress(title: "Exporting", operation: { _ in
        try await Task.sleep(nanoseconds: 5_000_000_000)
    })
}
job.cancel()

// Ask twice before cancelling, and allow the work longer to stop.
var options = ToastProgressOptions()
options.confirmsCancel = true
options.cancellationGrace = 20
toasts.track(title: "Deleting", options: options, onCancel: { /* stop the work */ })
```

- With `withProgress` or `handle.cancels(_:)`, the card finishes when the task ends.
- With a bare `onCancel`, call `handle.finishCancelled()` once the work has stopped.
- With no cancel route, the cancel finishes at once.
- The card then leaves with the stack's removal, and VoiceOver announces the cancel. A
  short "Cancelled" card replaces that when `showsCancelledResult` is on.
- **A cancel cannot hang.** If the work has not stopped after `cancellationGrace`, 10
  seconds by default, the card finishes as cancelled anyway. It is measured on the
  center's clock and checked at the next update or countdown change.
- `confirmsCancel` asks for a second tap within three seconds, and the button reads "Tap
  again to cancel" in between. VoiceOver's Cancel action never asks.

### Hidden or cancelled

Hiding and cancelling are different. Hiding takes the card off the screen and leaves the
work alone; see [Progress toasts are hidden, not cancelled](#progress-toasts-are-hidden-not-cancelled).
What happens when hidden work ends is up to `resultWhenHidden`:

```swift
// Dismissing hides a running card; the work, and the handle, carry on.
let handle = toasts.track(title: "Uploading", group: "upload")
toasts.dismiss(id: handle.id)

var options = ToastProgressOptions()
options.resultWhenHidden = .always          // .failureOnly (the default), .always or .never
options.showsCancelledResult = true
options.announcements = .startAndEnd        // .milestones(step:minimumInterval:) by default
options.successDuration = .seconds(2)
options.failureDuration = .indefinite

// Swiping cancels as well as hides.
options.swipeActions = ToastSwipeActions(leading: .cancelProgress, trailing: .hideProgress)
let backup = toasts.track(title: "Backing up", options: options, onCancel: { /* stop the work */ })
backup.succeed()
```

| `resultWhenHidden` | A result that arrives while the card is hidden |
| --- | --- |
| `.failureOnly` | A failure is presented as a new arrival, because the user may need to act on it. A success passes silently. The default. |
| `.always` | Success and failure are both presented. |
| `.never` | Neither is. |

A cancel while hidden is always silent. `isTracking(id:)` stays `true` for a hidden card
for as long as its work goes on.

### Options

| `ToastProgressOptions` | Default | Meaning |
| --- | --- | --- |
| `successDuration` | `.automatic` | How long a success stays up once it is in front. |
| `failureDuration` | `.seconds(8)` | The same for a failure, long enough to reach Retry. `.indefinite` asks for acknowledgement. |
| `resultWhenHidden` | `.failureOnly` | See above. |
| `announcements` | `.milestones(step: 0.25, minimumInterval: 5)` | What VoiceOver is told while the work runs. `.startAndEnd` and `.none` say less. |
| `cancellationGrace` | `10` | Seconds a cancel may take. |
| `showsCancelledResult` | `false` | Show a short "Cancelled" card instead of just removing the card. |
| `confirmsCancel` | `false` | Ask for a second tap before Cancel takes effect. |
| `swipeActions` | `.progress` | What swiping does while the work runs: hide, both ways. |

## Actions: tap, swipe, press and hold

Every gesture on the front card runs a `ToastAction`.

| Gesture | Runs | Default |
| --- | --- | --- |
| Tap | `tapAction`, or the stack's `onTap` | Nothing; taps pass through to the content behind. |
| Swipe toward the leading side | `swipeActions.leading` | `.delete`: the toast is removed. |
| Swipe toward the trailing side | `swipeActions.trailing` | `.later`: the toast comes back the next time the page is opened. |
| Press and hold, then carry | Either swipe action, chosen on a track | Shows both, with their icons, titles and subtitles. |

In a left-to-right layout, leading is left and trailing is right.

### What an action is

```swift
ToastAction(
    id: "archive",                       // what observers switch on; defaults to the title
    title: "Archive",                    // on the track, and read by VoiceOver
    subtitle: "Keeps a copy",            // a smaller line under the title on the track
    icon: .system("archivebox"),         // before the title on the track
    confirmation: "Archived",            // replaces the title once chosen on the track
    role: .subdued,                      // .destructive (red), .standard (indigo) or .subdued (graphite)
    effect: .dismiss                     // .dismiss, or .postpone to bring it back later
) { toast in
    store.archive(toast.id)              // runs before the effect
}
```

When an action runs, three things happen in order:

1. The action's own `handler` runs, given the toast.
2. Any `onToastAction` observer above the stack runs (see below).
3. The action's effect is applied: the toast is removed (`.dismiss`) or postponed
   (`.postpone`).

### Tapping

Give a toast its own tap action:

```swift
toasts.present(ToastMessage(
    title: "Moved to Trash",
    message: "Tap to undo",
    tapAction: ToastAction(id: "undo", title: "Undo") { toast in store.undo(toast.id) }
))
```

Or handle taps for the whole stack. `onTap` runs for any toast without a tap action of its
own, and the toast is then dismissed:

```swift
MyScreen()
    .toasts(toasts) { toast in
        router.open(toast.id)
    }
```

A toast with neither does not intercept taps at all.

### Swiping

Every toast swipes to `.delete` on the leading side and `.later` on the trailing side
unless told otherwise. Replace either side, reword the built-ins, or turn a side off:

```swift
// Your own action on one side; the other keeps its default.
ToastSwipeActions(leading: ToastAction(title: "Archive", icon: .system("archivebox")) { toast in
    store.archive(toast.id)
})

// The built-ins, reworded. Anything left out keeps the built-in value.
ToastSwipeActions(
    leading: .delete(title: "Remove", confirmation: "Removed"),
    trailing: .later(title: "Snooze", subtitle: "Next visit", icon: .system("moon.zzz"))
)

// One way only: swiping right barely moves the card.
ToastSwipeActions(leading: .delete, trailing: nil)

// No swiping and no press-and-hold: the toast leaves by tap, by timeout, or from code.
ToastSwipeActions.disabled
```

Pass the result as `swipeActions:` when you present:

```swift
toasts.present(ToastMessage(title: "Message from Ana", swipeActions: ToastSwipeActions(
    leading: .delete,
    trailing: .later(title: "Snooze")
)))
```

A swipe runs once the card travels 88 pt, or on a quick flick, and the card flies off that
way first. A shorter swipe springs back. Toward a side with no action, the card gives
only a little and always springs back.

### Pressing and holding

Hold the front card still for about half a second. It shrinks to half size, its glass
thins, and a translucent band appears across the stack. The band curves gently toward the
stack's edge, with each swipe action at its end in that action's colour. Carry the card
along the band. Past 64 pt the end it is heading for lights up and ticks; let go there to
run that action, or anywhere short of it to put the card back. The chosen end shows the
action's `confirmation` for a moment before the action runs.

This is the same pair of actions a quick swipe runs. Pressing and holding lets the user
read them first. A toast with no swipe actions ignores the long press.

### Observing every action

To handle actions in one place, by id, add an observer. It runs for taps, swipes, track
choices and VoiceOver actions, after the action's own handler:

```swift
MyScreen()
    .toasts(toasts)
    .onToastAction { toast, action in
        switch action.id {
        case ToastAction.deleteID: analytics.log("toast.deleted")
        case ToastAction.laterID: analytics.log("toast.postponed")
        case "archive": store.archive(toast.id)
        default: break
        }
    }
```

The built-in ids are `ToastAction.deleteID`, `ToastAction.laterID` and, for the stack's
`onTap`, `ToastAction.tapID`.

### Later: postponed toasts

An action with `effect: .postpone` (the built-in `.later` has it) takes the toast off
screen and keeps it in `center.postponed`. The stack brings postponed toasts back each
time it appears. Inside a `TabView` or a `NavigationStack`, that is the next time the user
returns to that tab or pops back to that page. They return oldest first, so the toast
postponed last is in front, each with a fresh countdown.

```swift
toasts.postponed            // waiting, oldest first
toasts.restorePostponed()   // bring them back now
toasts.discardPostponed()   // forget them
```

Postponed toasts live as long as the center. `dismiss(id:)` forgets a postponed toast too,
and so does `dismiss(group:)` by default. `dismissAll()` clears only the screen, so
whatever was put off stays put off; `dismissAll(removal: nil, scope: .everywhere)` clears
both. See [Dismissing toasts](#dismissing-toasts). To keep postponed toasts across
launches, save what you need from `postponed` and present again.

## Styling

### The default: glass

`GlassToastStyle` (`.glass`) is used unless you choose another style. It draws a frosted
pane tinted by the toast's status, with the glyph on a tinted chip. Restyle it without
writing a style by supplying a `ToastTheme`:

```swift
MyScreen()
    .toasts(toasts)
    .toastTheme(ToastTheme(
        titleFont: .headline,
        tint: { status in status == .notification ? .pink : ToastTheme.standardTint(status) },
        cornerRadius: 16
    ))
```

| Token | Default | Used for |
| --- | --- | --- |
| `material`, `surfaceFill`, `opaqueSurfaceFill`, `borderSubtle` | regular material, 4% primary, background, 25% primary | The glass pane, and its Reduce Transparency and Increase Contrast fallbacks. |
| `textPrimary`, `textSecondary`, `titleFont`, `messageFont` | primary, secondary, callout medium, footnote | The text. A font set here beats the one in `ToastMetrics`. |
| `tint` | secondary, orange, red, accent | One colour per status. The wash, edge, glyph and glow all derive from it. Build one with `ToastTheme.statusTint(normal:warning:error:notification:)`. |
| `cornerRadius`, `contentPadding`, `shadow` | 22, 14/16, soft | The card's shape and elevation. A radius or padding set here beats the one in `ToastMetrics`. |
| `edgeInset` | 8 | The gap between the stack and its edge. Applies to every style. |
| `stackMotion`, `flingMotion`, `snapBackMotion` | springs | Cards arriving and restacking, the swipe-out, the spring-back. Applies to every style. |
| `actionTint` | red, indigo, graphite | One colour per action role, on the track. |
| `actionFadeStart` | ⅓ | How far in from each end the track's colour stays solid before fading out at the centre. |
| `liftedMaterial` | ultra-thin material | The thinner pane of a card lifted onto the track. |
| `feedback` | per status | The arrival haptic. Return `nil` for silence. |

### Using your app's colours

If your app already has a palette, such as colour sets in an asset catalog or a design
system's `Color` extensions, map its tokens onto a theme once and apply it at the root.
ToastKit does not look up colours by name: you pass them in. With generated colour symbols,
a renamed or missing token is then a compile error rather than a toast that silently draws
clear.

```swift
extension ToastTheme {
    static let brand = ToastTheme(
        textPrimary: .brandTextPrimary,
        textSecondary: .brandTextSecondary,
        tint: ToastTheme.statusTint(
            normal: .brandNeutral,
            warning: .brandWarning,
            error: .brandDanger,
            notification: .brandAccent
        ),
        actionTint: { role in
            role == .destructive ? .brandDanger : ToastTheme.standardActionTint(role)
        }
    )
}

ContentView()
    .toasts(toasts)
    .toastTheme(.brand)
```

`.brandDanger` and the others are the symbols Xcode generates for an asset catalog's
colour sets (Xcode 15 and later, on by default in new projects). Hand-written
`static let` colours work the same way.

- `statusTint` takes one colour per status. Any status you leave out keeps its standard
  colour, so `ToastTheme.statusTint(error: .brandDanger)` changes only errors.
- Asset catalog colours keep their light, dark and high-contrast variants. The kit
  derives every shade from the tint as it draws, so the toasts follow the appearance
  with no extra work.
- `normal` uses its tint only for the glyph. Its surface stays clear and its border
  neutral, so a routine message never looks like a warning.
- The washes are fixed proportions of the tint (16% for warnings and errors, 14% for
  notifications), tuned for saturated mid-tone hues. If a very pale or very dark token
  gives a weak wash, map that status to a stronger token in the same palette.
- The default `notification` colour is the app's accent colour, so an `AccentColor` in
  the asset catalog already carries through without a theme.

### Unstyled: plain

`PlainToastStyle` (`.plain`) draws the icon, title and message and nothing else: no
surface, no colour, no fixed type. It is the starting point for your own look.

```swift
MyScreen()
    .toasts(toasts)
    .toastStyle(.plain)
```

### Your own style

Conform to `ToastStyle` and lay out the configuration's parts:

```swift
struct BannerToastStyle: ToastStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
            VStack(alignment: .leading, spacing: 2) {
                configuration.title.bold()
                configuration.message?.font(.footnote)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.indigo, in: .rect(cornerRadius: 14))
        .opacity(configuration.isLifted ? 0.85 : 1)
    }
}

MyScreen()
    .toasts(toasts)
    .toastStyle(BannerToastStyle())
```

The configuration offers the parts ready to use, and the raw toast for anything else:

| Property | |
| --- | --- |
| `icon` | An `Image`: the toast's own icon, or its status symbol. |
| `title` | The title as unstyled `Text`. |
| `message` | The message as unstyled `Text`, or `nil`. |
| `status` | The toast's status, for choosing colours. |
| `isLifted` | True while the card rides the press-and-hold track. The kit already shrinks it; a style may also thin its surface so the track shows through. |
| `isTappable` | True when tapping runs an action, for a chevron or similar hint. |
| `metrics` | The `ToastMetrics` in effect, with the theme's explicit fonts, radius and padding laid over the size's. See [Sizes](#sizes). |
| `progress` | A `ToastProgressConfiguration` for a [progress toast](#progress-toasts), otherwise `nil`. |
| `toast` | The whole `ToastMessage`. |

Fill the width you are given; the stack sets each card's width. The kit scales, moves,
tilts and fades whatever the style returns, so a style never handles gestures.

Wrapping the plain style is a quick way to get a custom surface:

```swift
struct CardToastStyle: ToastStyle {
    static var drawsProgress: Bool { PlainToastStyle.drawsProgress }

    func makeBody(configuration: Configuration) -> some View {
        PlainToastStyle().makeBody(configuration: configuration)
            .padding()
            .background(.background, in: .rect(cornerRadius: 12))
            .shadow(radius: 8, y: 4)
    }
}
```

### A progress toast in your own style

`configuration.progress` is `nil` for an ordinary toast, and for a progress toast that has
finished, other than a failure that offers Retry. Otherwise it holds the `phase`, the
live `value`, the `detail` and `percent` as `Text?`, whether Cancel and Retry are
available, and the parts ready to lay out: `bar`, `cancelButton` and `retryButton`.
Declare that your style draws them with `drawsProgress`, and size things from
`configuration.metrics`:

```swift
struct ProgressStyleExample: ToastStyle {
    static var drawsProgress: Bool { true }

    func makeBody(configuration: Configuration) -> some View {
        let metrics = configuration.metrics
        VStack(alignment: .leading, spacing: metrics.progressSpacing) {
            configuration.title
                .font(metrics.titleFont)
                .lineLimit(configuration.progress == nil ? metrics.titleLineLimit : metrics.progressTitleLineLimit)
            if let progress = configuration.progress {
                if let detail = progress.detail {
                    detail.font(metrics.messageFont).monospacedDigit()
                }
                HStack(spacing: 8) {
                    progress.bar
                    progress.cancelButton
                    progress.retryButton
                }
            } else if let message = configuration.message {
                message.font(metrics.messageFont)
            }
        }
        .padding(metrics.contentPadding)
        .background(.background, in: .rect(cornerRadius: metrics.cornerRadius))
    }
}
```

A style that leaves `drawsProgress` at its default, `false`, still works: the kit adds a
default bar and button under whatever it draws, so a style written before progress
toasts never shows a progress toast without them. `GlassToastStyle` and `PlainToastStyle`
draw their own. `ToastProgressBar(value:metrics:)` is public too, for a bar of your own
anywhere: `nil` is indeterminate. A style that wraps `.plain` or `.glass` must forward
`drawsProgress`, or the progress parts are drawn twice.

## Placement

```swift
MyScreen().toasts(toasts)                    // .bottom, the default
MyScreen().toasts(toasts, placement: .top)   // hangs from the top of the safe area
```

The stack hangs from its edge. The newest card sits nearest the edge and older ones
recede inward. The swipe path and the press-and-hold track both bend gently toward that
edge.

### What sits at the bottom

The bottom of an app's screen is rarely empty: a tab bar, an accessory above it, a mini
player, or a custom bar. The stack stays clear of all of them in two ways.

**1. The safe area, for system bars.** The stack sits inside the safe area of the view
`.toasts(_:)` is applied to. Apply it to a tab's content, not around the `TabView`. Inside
the tab, the tab bar is part of the safe area. On iOS 26 the tab view's bottom accessory
is covered too. Expanded, it is part of the safe area. Collapsed inline beside a minimized
tab bar, it sits within the bar's own row. Either way the stack stays above it as it
changes, with no setup.

```swift
TabView {
    Tab("Home", systemImage: "house") {
        HomeView()
            .toasts(toasts)          // inside the tab: above the tab bar
    }
}
.tabViewBottomAccessory { NowPlayingBar() }   // iOS 26: already in the tab's safe area
```

**2. Obstructions, for everything else.** Mark a view the safe area does not know about
with `toastObstruction()`. Each stack that can see it measures it and lifts itself just
clear of it. The stack follows the view as it grows, shrinks, moves or goes away.

```swift
// A custom tab bar drawn over the content, which changes height.
ZStack(alignment: .bottom) {
    ScreenContent()
    MyTabBar()
        .frame(height: isExpanded ? 96 : 56)
        .toastObstruction()
}
.toasts(toasts)
```

A stack sees views marked inside the view `.toasts(_:)` is applied to. When the marked
view and the stack are not one inside the other, apply `toastObstructionScope()` to a view
that contains both. A common case is a bar hosted around a `NavigationStack` while the
toasts live on a page inside it:

```swift
NavigationStack {
    LibraryView()
        .toasts(toasts)
}
.safeAreaInset(edge: .bottom) {
    MiniPlayer()
        .toastObstruction(isPlaying)   // false stops counting it
}
.toastObstructionScope()
```

Only views on the stack's own side count, so a bottom stack ignores a marked bar at the
top. Where a marked view is already outside the stack's safe area, the stack doesn't move
for it. You can mark a bar and also inset the safe area for it without lifting the stack
twice.

If your custom tab bar is added with `.safeAreaInset(edge: .bottom)` on the content that
hosts the stack, it is in the safe area already and needs no marking.

### More positions later

`ToastPlacement` is a struct rather than an enum, so positions such as a centred or
corner placement can be added without breaking anyone's `switch`. See
[Roadmap](#roadmap).

## Sizing

### Width

Cards are measured against the width available inside the safe area:

```swift
.toasts(toasts)                          // 60% of the safe-area width (the default)
.toasts(toasts, width: .fraction(0.9))   // 90%
.toasts(toasts, width: .fraction(1))     // the full safe-area width; the maximum
.toasts(toasts, width: .points(320))     // a fixed width, clamped to the maximum
```

On watchOS the default is the full width, since 60% of a watch is too narrow to read.

### Sizes

`ToastMetrics` sets how big cards are: width, padding, type, the glyph chip, corner
radius, line limits and the long-press track. It is separate from the theme and the style,
so they combine freely. Choose one of three presets, or build your own:

```swift
.toasts(toasts)
.toastMetrics(.compact)     // .compact, .regular (the default) or .large

.toastMetrics(ToastMetrics(
    width: .fraction(0.8),
    cornerRadius: 12,
    messageLineLimit: 3,
    progressBarHeight: 6
))
```

Like the style and the theme, `toastMetrics(_:)` is read from the environment, so it goes
outside `.toasts(_:)`. `.regular` matches what the kit drew before on iOS, macOS and
visionOS, and is the full width on watchOS. The one other difference is that Dynamic Type
is now capped at `accessibility1`, so text no longer grows through the largest accessibility
sizes. Every parameter of the initializer defaults to its
`.regular` value.

| Preset | iOS | macOS | watchOS | visionOS |
| --- | --- | --- | --- | --- |
| `.compact` | 50% wide, 10/12 padding, radius 16 | 280 pt, 8/10, 12 | full width, 8/10, 14 | 50%, 12/14, 20 |
| `.regular` | 60%, 14/16, 22 | 60%, 14/16, 22 | full width, 14/16, 22 | 60%, 14/16, 22 |
| `.large` | 80%, 18/20, 28 | 480 pt, 16/18, 22 | full width, 12/14, 24 | 70%, 20/24, 32 |

The size of a [progress toast](#progress-toasts)'s parts follows the preset as well. For
each, the table gives the bar's height, then the lines the title and the detail take
while the work runs:

| Preset | iOS | macOS | watchOS | visionOS |
| --- | --- | --- | --- | --- |
| `.compact` | 3 pt, 1, 1 | 3 pt, 1, 1 | 3 pt, 1, none: the percentage only | 4 pt, 1, 1 |
| `.regular` | 4 pt, 1, 1 | 4 pt, 1, 1 | 4 pt, 1, 1 | 5 pt, 1, 1 |
| `.large` | 6 pt, 2, 1 | 5 pt, 2, 1 | 5 pt, 2, 1 | 7 pt, 2, 1 |

Type and the glyph chip step along with them. On macOS the compact and large widths are
fixed points, because a window can be any size. On watchOS every preset is the full width,
so `.large` means bigger type rather than a wider card.

How the settings combine:

- **Width:** a `width:` you pass to `.toasts(_:width:)` always beats the preset's. Passing
  `.default` asks for 60%, even on the watch.
- **Theme:** a title font, message font, corner radius or content padding you set on a
  `ToastTheme` beats the preset's, so a brand theme keeps its look in every size.
- **Stack:** each buried card peeks out by the average of the preset's top and bottom
  padding (14 pt for `.regular`), so a roomier preset shows a deeper stack. A theme's
  `contentPadding` does not change it.
- **Long press:** the track's band, its height and its labels scale with the preset, so a
  large card still fits. The distance a finger travels to arm an action does not change.
- **Line limits:** `titleLineLimit` and `messageLineLimit` live in the metrics: 2 and 2,
  or 3 and 4 for `.large`. Set one to `nil` for no limit.
- **Dynamic Type:** toast content stops growing at `accessibility1`. Change it with
  `maximumDynamicTypeSize`.
- **Progress:** `progressBarHeight` is the bar's thickness and `progressSpacing` the gap
  between the text and the bar, 8 pt. `progressTitleLineLimit` and
  `progressDetailLineLimit` are the lines the title and the detail line may take while the
  work runs; a detail limit of `0` hides the line, which is how the compact size on
  watchOS shows only the percentage. `progressButtonSide` is the drawn size of Cancel and
  Retry: 28 pt on iOS, 22 on macOS, 32 on watchOS and visionOS. The touch target around
  it is larger: at least 44 pt on iOS and watchOS, 60 on visionOS, 28 on macOS.
- **Height:** a running card keeps one height. While the work runs, the title uses the
  progress line limit and the detail line uses monospaced digits, so a tick never
  changes the card and the cards beneath do not shift. When the work ends, the normal
  `titleLineLimit` and `messageLineLimit` apply again.

Width, the stack offset, the long-press track's scale and label fonts, and the Dynamic Type
limit apply to every style, `.plain` included. Padding, title and message fonts, the glyph
chip, corner radius and line limits are drawn only by the glass style; `.plain` and your own
styles can read them from `configuration.metrics`, which already has the theme's explicit
fonts, radius and padding laid over the preset's.

## Accessibility

- Each card is one VoiceOver element: title, then message. A tappable card is a button,
  and its hint says so.
- Both swipe actions are offered by name in the actions rotor, along with **Dismiss**. No
  gesture is ever the only way to reach an action.
- Buried cards are hidden from VoiceOver; only the front card is reachable.
- **Reduce Motion:** cards cross-fade instead of sliding, the swipe path flattens, and the
  tilt is dropped. Every removal, whatever `removal:` asks for, is a cross-fade, and all
  departing cards fade together. A progress bar stops sweeping and fills without
  animating, and an indeterminate bar becomes a still, half-opaque track with "In
  progress" for its detail. A card that finishes cross-fades into its result.
- A batch removal (`dismiss(group:)`, `dismiss(where:)`, `dismissAll()`) is announced
  once, as "3 notifications dismissed", instead of leaving VoiceOver to notice cards
  vanishing. The text is localized and pluralized.
- **Progress toasts** are read with their progress, such as "42%, 12 MB of 30 MB", as the
  card's value, and are marked as updating often, so VoiceOver does not announce every
  tick. Cancel, Hide and Retry are named actions in the rotor; Cancel only while the work
  runs, and Dismiss is left out while it does. The buttons on the card are hidden from
  VoiceOver, because the card is one element.
- While the work runs, VoiceOver is told when it starts, at every quarter of the way and
  at the end, never more often than every five seconds, and only for the front card
  while the app is active. A milestone held back by the interval is folded into the next
  one, which gives the latest value. A card that is buried or hidden announces only
  its outcome. Failures are announced as urgent on iOS and macOS; on watchOS and
  visionOS they are announced without a priority. Change what is said with
  `ToastProgressOptions.announcements`.
- **Reduce Transparency:** the glass pane and the track turn opaque. The status colour
  stays, because it carries meaning.
- **Increase Contrast:** the glass style's gradient edge becomes a solid border.
- **Dynamic Type:** text and the glyph chip scale, up to `accessibility1`.

These are read from the SwiftUI environment, so they work on every platform with no setup.

## Platforms and localization

| Platform | Minimum | Notes |
| --- | --- | --- |
| iOS, iPadOS | 17 | |
| macOS | 14 | Swipe by clicking and dragging. Cancel and Retry have a tooltip. |
| watchOS | 10 | Toasts are full width by default; the track fits down to about 184 pt. Progress toasts show only the percentage at the compact size, and Cancel is 32 pt drawn inside a 44 pt target. A watch app may be suspended, so run long transfers in your own background `URLSession` and let the toast report on them. |
| visionOS | 1 | No haptics: `SensoryFeedback` arrived in visionOS 26, and a headset has nothing to vibrate. Buttons react to the gaze and have a 60 pt target. |
| tvOS | — | Not supported: there is no drag gesture, and swiping is the primary interaction. A tvOS toast needs focus-driven dismissal, which is a redesign. |

The kit's own strings, such as the built-in action titles and VoiceOver hints, ship in
English, Simplified Chinese, Traditional Chinese and Japanese, from the package's own
bundle. Your toasts' text is yours to localize.

## Testing your code

`ToastCenter` takes a scheduler, so tests can drive the countdown without waiting:

```swift
@MainActor
final class FakeScheduler: ToastScheduling {
    var now = Date()
    private var pending: (@MainActor () -> Void)?
    func schedule(after seconds: TimeInterval, action: @escaping @MainActor () -> Void) {
        pending = action
    }
    func cancel() { pending = nil }
    func fire() { pending?() }
}

let toasts = ToastCenter(scheduler: FakeScheduler())
```

A running progress toast has no countdown, and a cancel gives up after its grace
period, both of which the fake scheduler shows without waiting. The milestone
announcements are internal, so the package's own tests cover those.

```swift
let scheduler = FakeScheduler()
let toasts = ToastCenter(scheduler: scheduler)

// A running progress toast is never timed.
let upload = toasts.track(title: "Uploading", onCancel: {})
scheduler.fire()
XCTAssertTrue(toasts.isTracking(id: upload.id))

// Cancel waits for the work to stop, but only for the grace period.
upload.cancel()
XCTAssertEqual(upload.phase, .cancelling)
scheduler.now += 11
toasts.present(.normal, title: "Anything")          // any update or reconcile checks the grace
XCTAssertFalse(toasts.isTracking(id: upload.id))
```

The package's own tests run with `swift test`. They cover the countdown rules, durations,
postponing, swipe thresholds, the track's geometry and the obstruction lift. Dismissal is
tested on the model alone: groups, scopes, the countdown across a batch, the departures
the stack draws, the direction maths and the trail's stagger and keyframes. A batch
removal needs no clock beyond the fake scheduler, because the countdown never waits for
the animation. Progress
toasts are tested on the model too: phases and outcomes, hiding and eviction, retry and
cancel, the coalescing of updates, the milestone throttle and the VoiceOver announcements,
and the Foundation `Progress` mapping. They also
compile this README's examples against the public API
(`Tests/ToastKitTests/DocumentationExamples.swift`). The exception is the iOS 26
`TabView` snippet, which needs a newer SDK than the package's minimum.

## Architecture

| Layer | Types | Imports |
| --- | --- | --- |
| Model | `ToastCenter`, `ToastMessage`, `ToastDuration`, `ToastAction`, `ToastSwipeActions`, `ToastIcon`, `ToastWidth`, `ToastScheduling`, `ToastGroup`, `ToastDismissalScope`, `ToastRemoval`, `ToastRemovalDirection`, `ToastProgress`, `ToastProgressPhase`, `ToastProgressHandle`, `ToastProgressReporter`, `ToastProgressOptions`, `ToastProgressResult`, `ToastProgressCompletion`, and the departure planning and trail timing behind them | Foundation, CoreGraphics |
| Behaviour | `ToastStack`, `ToastCard`, the press-and-hold track, obstructions | SwiftUI |
| Appearance | `ToastStyle`, `GlassToastStyle`, `PlainToastStyle`, `ToastTheme`, `ToastMetrics`, `ToastProgressConfiguration`, `ToastProgressBar` | SwiftUI |

- The model holds no colours or views, so its rules are unit-tested without a host.
- The behaviour layer draws nothing; it hands each card to the style in effect.
- The app owns identity. The kit owns proportion: how far cards peek, how strongly the
  tint washes the glass, and how the track fades.

## Roadmap

- More placements: centred, and the top and bottom corners for large screens.
- Verified right-to-left mirroring of the swipe sides. Leading and trailing currently
  follow the drag's left and right.
- A track style, so the press-and-hold band can be redrawn the way cards can.
- tvOS, with focus-driven actions.

## License

ToastKit is available under the MIT License. See [LICENSE](LICENSE).
