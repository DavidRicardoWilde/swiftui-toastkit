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

### Acting on toasts

- ``ToastAction``
- ``ToastSwipeActions``

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

### Testing

- ``ToastScheduling``
- ``ToastTaskScheduler``
