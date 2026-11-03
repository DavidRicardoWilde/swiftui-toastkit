# Progress toasts

Show work that takes a while, let people cancel it, and turn the card into its result where
it stands.

## Overview

A progress toast is a persistent card for work that is still going: an upload, an export, a
sync. It is never timed while the work runs. It draws a bar, can offer Cancel, and keeps
its id and its place in the stack when it becomes a success or a failure.

Present one with ``ToastCenter/track(id:title:message:icon:progress:group:options:onCancel:)``
and keep the ``ToastProgressHandle`` it returns until the work ends. A handle that is
released without an outcome is abandoned: the work is cancelled through its cancel route,
if it has one, and the card is removed.

```swift
let handle = toasts.track(title: "Syncing", group: "sync")   // indeterminate; never times out
handle.update(.items(3, of: 10))                             // "3 of 10"
handle.update(fraction: 0.8)
handle.succeed(ToastProgressResult(title: "Synced", message: "10 items"))
```

### Describing progress

``ToastProgress`` is a `Sendable` value: ``ToastProgress/indeterminate``,
``ToastProgress/fraction(_:subtitle:)``, ``ToastProgress/bytes(_:of:)`` or
``ToastProgress/items(_:of:)``. Bytes and items write their own detail line, in the user's
locale, and a subtitle replaces it. While the work runs, the card's ``ToastProgressPhase``
is `running`; it moves to `cancelling` when Cancel is pressed, and ends as `succeeded`,
`failed` or `cancelled`.

### Async work and Foundation progress

``ToastCenter/withProgress(id:title:message:icon:group:cancellable:success:failure:onRetry:options:operation:)``
runs an operation, reports through a ``ToastProgressReporter`` that is safe to call from
any thread, and decides the outcome from how the operation ends: a returned value succeeds,
a cancellation cancels, any other error fails and is rethrown.

```swift
let url = try await toasts.withProgress(
    title: "Uploading video",
    group: "upload",
    operation: { report in
        try await uploader.upload(file) { sent, total in report(.bytes(sent, of: total)) }
    }
)
```

``ToastCenter/track(_:id:title:message:icon:group:completion:options:)`` follows a
Foundation `Progress`, such as `URLSessionTask.progress`. With ``ToastProgressCompletion/automatic(success:)``,
the default, the card succeeds when the `Progress` finishes and the handle may be dropped.
With ``ToastProgressCompletion/manual`` the outcome is yours.

### Failure and retry

``ToastProgressHandle/fail(_:retry:)`` turns the card into an error that stays for
``ToastProgressOptions/failureDuration``, eight seconds by default. When a retry closure
is given, the card offers Retry. Start the new run with the same `id`, synchronously or in
a `Task` created inside the closure, and the card resumes in place; otherwise it is
removed once the closure returns.

```swift
handle.fail(ToastProgressResult(message: "No connection")) {
    send(toasts, id: id)     // the same id: the card resumes in place
}
```

### Cancellation

Cancel is offered while the work runs and a way to stop it exists: an `onCancel` closure,
``ToastProgressHandle/cancels(_:)``, a cancellable `Progress`, or a cancellable
`withProgress`. The card shows "Cancelling…" until the work stops, and finishes as
cancelled anyway after ``ToastProgressOptions/cancellationGrace``, ten seconds by default,
so it cannot hang. ``ToastCenter/cancelProgress(group:)`` cancels every running card in a
group, and ``ToastProgressOptions/confirmsCancel`` asks for a second tap first.

```swift
let handle = toasts.track(title: "Uploading video", group: "upload")
handle.cancels(upload)          // Cancel cancels the Task
toasts.cancelProgress(group: "upload")
```

### Hiding is not cancelling

Dismissing a running card, by swiping it, with `dismiss(id:)` or with a batch call, hides
it: the work carries on, ``ToastProgressHandle/isVisible`` turns `false`, and no
dismissal scope reaches the card. A card pushed out by capacity is hidden too, after the
timed toasts and before the ordinary persistent ones. What happens to a result that
arrives while the card is hidden is set by ``ToastProgressOptions/resultWhenHidden``:
a failure comes back as a new arrival by default, and a success passes silently.

To make swiping cancel as well, replace ``ToastSwipeActions/progress``, which hides in
both directions, with your own pair:

```swift
var options = ToastProgressOptions()
options.swipeActions = ToastSwipeActions(leading: .cancelProgress, trailing: .hideProgress)
```

### Styling and sizing

``ToastStyleConfiguration/progress`` gives a custom style a ``ToastProgressConfiguration``
with the live value and a ready-made bar, Cancel button and Retry button. A style that
draws them sets ``ToastStyle/drawsProgress``; one that does not still gets a default bar
and button added under it. A style that wraps `.plain` or `.glass` must forward
`drawsProgress`, or the progress parts are drawn twice. ``ToastMetrics`` sets the bar's height and the lines a running
card may take, so ticks never change a card's height.

### Accessibility

The card is one VoiceOver element whose value is the progress, such as "42%, 12 MB of
30 MB", marked as updating often. Cancel, Hide and Retry are named actions. VoiceOver is
told when the work starts, at each quarter of the way (never more often than every five
seconds, and only for the front card while the app is active) and when it ends; failures
are urgent on iOS and macOS. ``ToastProgressOptions/announcements`` changes this. With
Reduce Motion the bar stops sweeping and fills without animating.

## Topics

### Starting and reporting

- ``ToastCenter/track(id:title:message:icon:progress:group:options:onCancel:)``
- ``ToastCenter/track(_:id:title:message:icon:group:completion:options:)``
- ``ToastCenter/withProgress(id:title:message:icon:group:cancellable:success:failure:onRetry:options:operation:)``
- ``ToastProgressHandle``
- ``ToastProgressReporter``
- ``ToastProgress``
- ``ToastProgressPhase``

### Ending and cancelling

- ``ToastProgressResult``
- ``ToastProgressCompletion``
- ``ToastCenter/cancelProgress(group:)``
- ``ToastCenter/isTracking(id:)``

### Configuring

- ``ToastProgressOptions``
- ``ToastSwipeActions/progress``
- ``ToastAction/hideProgress``
- ``ToastAction/cancelProgress``

### Drawing

- ``ToastProgressConfiguration``
- ``ToastProgressBar``
