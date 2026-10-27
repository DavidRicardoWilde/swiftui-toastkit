# ``ToastKit``

Stacked, swipeable toast notifications for SwiftUI.

## Overview

ToastKit separates what a toast *does* from how it *looks*. A ``ToastCenter`` holds the
toasts and times them. A ``ToastStack`` draws them over your content and handles every
gesture. A ``ToastStyle`` draws each card: the frosted ``GlassToastStyle`` by default,
the bare ``PlainToastStyle``, or your own.

```swift
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

Each toast can be tapped, swiped toward either side, or pressed and held to show both
swipe actions on a curved track before choosing. By default a leading swipe deletes the
toast and a trailing swipe brings it back the next time the page is opened. Every action
is a ``ToastAction`` with its own title, subtitle, icon and handler.

Cards come in three sizes, ``ToastMetrics/compact``, ``ToastMetrics/regular`` and
``ToastMetrics/large``, applied with `toastMetrics(_:)`. A `width:` passed to the stack
always wins over the size's width, and Dynamic Type stops growing toast content at
`accessibility1`.

```swift
ContentView()
    .toasts(toasts)
    .toastMetrics(.compact)
```

Related toasts can share a ``ToastGroup`` and be dismissed together, as a batch, with a
choice of how they leave. A ``ToastRemoval`` is ``ToastRemoval/fade`` by default, or a
slide or a staggered trail in a ``ToastRemovalDirection``; a ``ToastDismissalScope``
picks whether the batch reaches the stack, the postponed toasts, or both. Set the default
exit for the whole stack with `toastRemoval(_:)`. With Reduce Motion, every removal is a
cross-fade.

```swift
toasts.present(.normal, title: "Uploading…", group: "upload")

toasts.dismiss(group: "upload", removal: .trail())
toasts.dismiss(removal: .slide(.trailing)) { $0.status == .error }
toasts.dismissAll(removal: .trail(.towardAnchor))
```

Work that takes a while can have a card of its own. ``ToastCenter/track(id:title:message:icon:progress:group:options:onCancel:)``
presents a progress toast that is never timed while the work runs, draws a bar, and can
offer Cancel. The handle it returns reports the work and ends it, and the card turns into
its success or failure where it stands. Dismissing a running card hides it and leaves the
work alone; cancelling is a separate call. See <doc:ProgressToasts>.

```swift
let handle = toasts.track(title: "Syncing", group: "sync")
handle.update(.items(3, of: 10))
handle.succeed(ToastProgressResult(title: "Synced"))
```

The stack sits at the bottom of the safe area by default, above a tab bar and its
accessory. To keep it clear of anything the safe area does not cover, such as a custom
tab bar, mark that view with `toastObstruction()`.

The package README is the full guide, with examples for every feature.

## Topics

### Presenting

- ``ToastCenter``
- ``ToastMessage``
- ``ToastDuration``
- ``ToastIcon``

### Progress

- <doc:ProgressToasts>
- ``ToastProgress``
- ``ToastProgressPhase``
- ``ToastProgressHandle``
- ``ToastProgressReporter``
- ``ToastProgressResult``
- ``ToastProgressCompletion``
- ``ToastProgressOptions``
- ``ToastProgressConfiguration``
- ``ToastProgressBar``

### Dismissing

- ``ToastGroup``
- ``ToastDismissalScope``
- ``ToastRemoval``
- ``ToastRemovalDirection``

### Acting on toasts

- ``ToastAction``
- ``ToastSwipeActions``
- ``ToastSwipeActions/progress``

### Drawing the stack

- ``ToastStack``
- ``ToastCard``
- ``ToastPlacement``
- ``ToastWidth``

### Styling

- ``ToastStyle``
- ``ToastStyleConfiguration``
- ``GlassToastStyle``
- ``PlainToastStyle``
- ``ToastTheme``
- ``ToastMetrics``

### Testing

- ``ToastScheduling``
- ``ToastTaskScheduler``
