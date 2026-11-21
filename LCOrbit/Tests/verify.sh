#!/bin/sh
# Build-output smoke check; behavior on a physical Guest still requires device tests.
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BINARY="${1:-$ROOT/dist/LCFloatingReturn.dylib}"
test -s "$BINARY"
test "$(xcrun lipo -archs "$BINARY")" = 'arm64'
xcrun vtool -show-build "$BINARY" | grep -q 'platform IOS'
xcrun vtool -show-build "$BINARY" | grep -q 'minos 16.0'
xcrun otool -D "$BINARY" | grep -Fq '@rpath/LCFloatingReturn.dylib'
SYMBOLS="$(xcrun nm -gU "$BINARY")"
for symbol in 'OBJC_CLASS_$_LCOrbitCore' 'OBJC_CLASS_$_LCOrbitHost' \
              'OBJC_CLASS_$_LCOrbitOverlayManager' 'OBJC_CLASS_$_LCOrbitEventBus' \
              'OBJC_CLASS_$_LCOrbitGuestService' \
              'OBJC_CLASS_$_LCOrbitMultitask' \
              'OBJC_CLASS_$_LCOrbitHostSettings' \
              'OBJC_CLASS_$_LCFloatingMenuModule' '_LCFloatingMenuRegisterWithOrbit'
do
    printf '%s\n' "$SYMBOLS" | grep -Fq "$symbol"
done
# The minimal return-only FloatingMenu intentionally drops drawer-specific UI.
# Retain only source contracts relevant to the new module and shared runtime.
grep -Fq -- '- (void)returnToLiveContainer' "$ROOT/LCFloatingMenu/LCFloatingMenu.m"
grep -Fq 'handleLongPress:' "$ROOT/LCFloatingMenu/LCFloatingMenu.m"
grep -Fq 'launchGuestPath:@"ui" uuid:nil error:&error' "$ROOT/LCFloatingMenu/LCFloatingMenu.m"
grep -Fq 'orbitDidStartWithContext:' "$ROOT/LCFloatingMenu/LCFloatingMenu.m"
grep -Fq 'orbitWillStop' "$ROOT/LCFloatingMenu/LCFloatingMenu.m"
grep -Fq 'LCFloatingMenuRegisterWithOrbit' "$ROOT/LCFloatingMenu/LCFloatingMenu.m"
grep -Fq 'if(created) _window.hidden=NO' "$ROOT/LCOrbit/Core/LCOrbitOverlayManager.m"
grep -Fq 'launchToGuestAppWithURL:' "$ROOT/LCOrbit/Core/LCOrbitGuestService.m"
echo 'LCOrbit minimal-menu build smoke checks: PASS'
