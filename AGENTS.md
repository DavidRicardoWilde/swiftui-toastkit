# Repository Guidelines

## Project Structure & Module Organization

ToastKit is a Swift Package that exposes one `ToastKit` library product. Production code is in `Sources/ToastKit/`; keep each public type in a focused file (for example, `ToastCenter.swift` or `ToastStyle.swift`). Package-owned localized strings live in `Sources/ToastKit/Resources/<locale>.lproj/Localizable.strings`. API documentation is in `Sources/ToastKit/ToastKit.docc/`. Tests mirror features in `Tests/ToastKitTests/`, while `DocumentationExamples.swift` compiles README snippets against the public API.

The package supports iOS 17+, macOS 14+, watchOS 10+, and visionOS 1+ with Swift 5.10. It deliberately has no dependencies beyond SwiftUI.

## Build, Test, and Development Commands

- `swift build` — compile the library and catch public-API build errors.
- `swift test` — run the XCTest suite, including README example compilation.
- `swiftlint` — check `Sources/` and `Tests/` using `.swiftlint.yml`; install SwiftLint locally if the command is unavailable.

Run `swift test` before opening a pull request. Use an Xcode scheme derived from `Package.swift` when manually exercising gestures or accessibility on a supported simulator or device.

## Coding Style & Naming Conventions

Follow the existing Swift style: four-space indentation, braces on the declaration line, and one focused responsibility per type. Use `UpperCamelCase` for types and `lowerCamelCase` for functions, properties, and enum cases. Prefer descriptive API labels, such as `dismissTopmost()` and `visibleDepth`.

Keep model logic independent of rendering where possible: Foundation/Observation types define behavior, while SwiftUI views compose the interaction and appearance layers. Add DocC-style `///` documentation to public APIs and preserve accessibility-aware behavior. Do not introduce force casts or force tries; SwiftLint enforces both.

## Testing Guidelines

Use XCTest with `@testable import ToastKit`. Name tests `test<ExpectedBehavior>()`, e.g. `testNewestToastBecomesTopmost`. Cover behavior changes with deterministic tests; inject a `ToastScheduling` fake for timing rather than sleeping. Update `DocumentationExamples.swift` or README snippets when a public API changes.

## Commit & Pull Request Guidelines

Use short, imperative commit subjects consistent with history, such as `Add MIT License`. Keep each commit narrowly scoped. Pull requests should explain the behavioral change, list validation performed (normally `swift test` and `swiftlint`), link related issues when present, and include screenshots or recordings for visible SwiftUI interaction changes.
