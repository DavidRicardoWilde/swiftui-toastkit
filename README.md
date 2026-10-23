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
- [Presenting toasts](#presenting-toasts)
- [How long a toast stays](#how-long-a-toast-stays)
- [Actions: tap, swipe, press and hold](#actions-tap-swipe-press-and-hold)
- [Styling](#styling)
- [Placement](#placement)
- [Width](#width)
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

Re-presenting an id updates a toast in place, which suits progress:

```swift
let syncID = UUID()
toasts.present(ToastMessage(id: syncID, title: "Syncing 3 items…", duration: .indefinite))
// later
toasts.present(ToastMessage(id: syncID, title: "Synced"))
```

Remove toasts from code with `dismiss(id:)`, `dismissTopmost()` or `dismissAll()`.

### The stack

The newest toast is drawn in front; up to `visibleDepth` (3) cards show, and older ones
recede behind it, slightly smaller and dimmer. Only the front card takes touches. Past
`capacity` (5) the oldest *timed* toasts are dropped first, so a toast the user has to
acknowledge (`duration: .indefinite`) survives a burst of routine ones.

```swift
let toasts = ToastCenter(visibleDepth: 2, capacity: 8)
```

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

Postponed toasts live as long as the center. `dismiss(id:)` forgets a postponed toast too.
`dismissAll()` clears only the screen, so whatever was put off stays put off. To keep
postponed toasts across launches, save what you need from `postponed` and present again.

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
| `textPrimary`, `textSecondary`, `titleFont`, `messageFont` | primary, secondary, callout medium, footnote | The text. |
| `tint` | secondary, orange, red, accent | One colour per status. The wash, edge, glyph and glow all derive from it. Build one with `ToastTheme.statusTint(normal:warning:error:notification:)`. |
| `cornerRadius`, `contentPadding`, `shadow` | 22, 14/16, soft | The card's shape and elevation. |
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
| `toast` | The whole `ToastMessage`. |

Fill the width you are given; the stack sets each card's width. The kit scales, moves,
tilts and fades whatever the style returns, so a style never handles gestures.

Wrapping the plain style is a quick way to get a custom surface:

```swift
struct CardToastStyle: ToastStyle {
    func makeBody(configuration: Configuration) -> some View {
        PlainToastStyle().makeBody(configuration: configuration)
            .padding()
            .background(.background, in: .rect(cornerRadius: 12))
            .shadow(radius: 8, y: 4)
    }
}
```

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

## Width

Cards are measured against the width available inside the safe area:

```swift
.toasts(toasts)                          // 60% of the safe-area width (the default)
.toasts(toasts, width: .fraction(0.9))   // 90%
.toasts(toasts, width: .fraction(1))     // the full safe-area width; the maximum
.toasts(toasts, width: .points(320))     // a fixed width, clamped to the maximum
```

## Accessibility

- Each card is one VoiceOver element: title, then message. A tappable card is a button,
  and its hint says so.
- Both swipe actions are offered by name in the actions rotor, along with **Dismiss**. No
  gesture is ever the only way to reach an action.
- Buried cards are hidden from VoiceOver; only the front card is reachable.
- **Reduce Motion:** cards cross-fade instead of sliding, the swipe path flattens, and the
  tilt is dropped.
- **Reduce Transparency:** the glass pane and the track turn opaque. The status colour
  stays, because it carries meaning.
- **Increase Contrast:** the glass style's gradient edge becomes a solid border.
- **Dynamic Type:** text and the glyph chip scale.

These are read from the SwiftUI environment, so they work on every platform with no setup.

## Platforms and localization

| Platform | Minimum | Notes |
| --- | --- | --- |
| iOS, iPadOS | 17 | |
| macOS | 14 | Swipe by clicking and dragging. |
| watchOS | 10 | Use a narrow `width`; the track fits down to about 184 pt. |
| visionOS | 1 | No haptics: `SensoryFeedback` arrived in visionOS 26, and a headset has nothing to vibrate. |
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

The package's own tests run with `swift test`. They cover the countdown rules, durations,
postponing, swipe thresholds, the track's geometry and the obstruction lift. They also
compile this README's examples against the public API
(`Tests/ToastKitTests/DocumentationExamples.swift`). The exception is the iOS 26
`TabView` snippet, which needs a newer SDK than the package's minimum.

## Architecture

| Layer | Types | Imports |
| --- | --- | --- |
| Model | `ToastCenter`, `ToastMessage`, `ToastDuration`, `ToastAction`, `ToastSwipeActions`, `ToastIcon`, `ToastWidth`, `ToastScheduling` | Foundation |
| Behaviour | `ToastStack`, `ToastCard`, the press-and-hold track, obstructions | SwiftUI |
| Appearance | `ToastStyle`, `GlassToastStyle`, `PlainToastStyle`, `ToastTheme` | SwiftUI |

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
