#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
OUT="${1:-$ROOT/dist/LCFloatingReturn.dylib}"
# Embed the source commit so Settings can compare against GitHub accurately.
BUILD_COMMIT="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
case "$BUILD_COMMIT" in
    *[!0-9a-f]*|"") BUILD_COMMIT="unknown" ;;
esac
BUILD_COMMIT_FLAG="-DFM_BUILD_COMMIT=@\"$BUILD_COMMIT\""

# The checked-in FloatingMenu source is the minimal return-only edition.
# Run tests for its retained contract and shared Orbit runtime only.
sh "$ROOT/LCOrbit/Build/test-minimal-menu.sh"
mkdir -p "$(dirname "$OUT")"
xcrun clang "$BUILD_COMMIT_FLAG" -arch arm64 -isysroot "$SDK" -miphoneos-version-min=16.0 -fobjc-arc -O2 \
    -dynamiclib -framework Foundation -framework UIKit -framework QuartzCore \
    -framework CoreGraphics -framework Security -install_name '@rpath/LCFloatingReturn.dylib' \
    "$ROOT/LCOrbit/Core/LCOrbitCore.m" \
    "$ROOT/LCOrbit/Core/LCOrbitHost.m" \
    "$ROOT/LCOrbit/Core/LCOrbitGuestUIKitDiagnostics.m" \
    "$ROOT/LCOrbit/Core/LCOrbitGuestService.m" \
    "$ROOT/LCOrbit/Core/LCOrbitMultitask.m" \
    "$ROOT/LCOrbit/Core/LCOrbitAutomaticPiP.m" \
    "$ROOT/LCOrbit/Core/LCOrbitMultitaskUI.m" \
    "$ROOT/LCOrbit/Core/LCOrbitTaskSwitcher.m" \
    "$ROOT/LCOrbit/Core/LCOrbitHostSettings.m" \
    "$ROOT/LCOrbit/Core/LCOrbitEventBus.m" \
    "$ROOT/LCOrbit/Core/LCOrbitOverlayManager.m" \
    "$ROOT/LCOrbit/Core/LCOrbitStorage.m" \
    "$ROOT/LCOrbit/Core/LCOrbitLog.m" \
    "$ROOT/LCFloatingMenu/LCFloatingMenu.m" \
    -o "$OUT"
file "$OUT"
xcrun lipo -info "$OUT"
sh "$ROOT/LCOrbit/Tests/verify.sh" "$OUT"
