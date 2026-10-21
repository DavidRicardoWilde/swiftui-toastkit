#!/usr/bin/env bash
# Generate the examples' Xcode project, build one example and launch it.
#
#   scripts/run-example.sh ios      [simulator name]   default: "iPhone 16 Pro"
#   scripts/run-example.sh macos
#   scripts/run-example.sh watchos  [simulator name]   default: "Apple Watch Series 10 (46mm)"
#   scripts/run-example.sh visionos [simulator name]   default: "Apple Vision Pro"
#
# Needs macOS with Xcode 16+ and XcodeGen (brew install xcodegen).
set -euo pipefail

platform="${1:-}"
root="$(cd "$(dirname "$0")/.." && pwd)"
derived="$root/examples/.build/DerivedData"

case "$platform" in
    ios)      scheme=iOSExample;      sdk=iphonesimulator; bundle=com.example.toastkit.ios;      sim="${2:-iPhone 16 Pro}" ;;
    watchos)  scheme=watchOSExample;  sdk=watchsimulator;  bundle=com.example.toastkit.watchos;  sim="${2:-Apple Watch Series 10 (46mm)}" ;;
    visionos) scheme=visionOSExample; sdk=xrsimulator;     bundle=com.example.toastkit.visionos; sim="${2:-Apple Vision Pro}" ;;
    macos)    scheme=macOSExample;    sdk=macosx;          bundle=com.example.toastkit.macos;    sim="" ;;
    *) echo "usage: $0 ios|macos|watchos|visionos [simulator name]" >&2; exit 64 ;;
esac

command -v xcodegen >/dev/null || { echo "XcodeGen is missing: brew install xcodegen" >&2; exit 69; }
(cd "$root/examples" && xcodegen generate --quiet)

if [[ "$platform" == macos ]]; then
    xcodebuild -project "$root/examples/ToastKitExamples.xcodeproj" -scheme "$scheme" \
        -configuration Debug -destination 'platform=macOS' -derivedDataPath "$derived" build
    open "$derived/Build/Products/Debug/$scheme.app"
    exit 0
fi

xcrun simctl boot "$sim" 2>/dev/null || true   # already booted is fine
open -a Simulator
xcodebuild -project "$root/examples/ToastKitExamples.xcodeproj" -scheme "$scheme" \
    -configuration Debug -sdk "$sdk" -destination "platform=$( [[ $sdk == iphonesimulator ]] && echo 'iOS Simulator' || ([[ $sdk == watchsimulator ]] && echo 'watchOS Simulator' || echo 'visionOS Simulator')),name=$sim" \
    -derivedDataPath "$derived" build
xcrun simctl install "$sim" "$derived/Build/Products/Debug-$sdk/$scheme.app"
xcrun simctl launch "$sim" "$bundle"
