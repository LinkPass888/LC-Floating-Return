#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/LCFloatingMenu/LCFloatingMenu.m"
# Contract smoke test for the deliberately small return-button module.
python3 - "$SOURCE" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
required=[
 '@interface FMReturnManager',
 '- (void)installIfPossible',
 '- (void)refreshUI',
 '- (void)returnToLiveContainer',
 '- (void)handleLongPress:',
 '- (void)openSettingsInScene:',
 'launchGuestPath:@"ui" uuid:nil error:&error',
 'UILongPressGestureRecognizer *hold',
 '- (void)closeSettings',
 'LCFloatingMenuRegisterWithOrbit',
 'FM_MENU_VERSION @"0.1.0"',
 'LCOrbitOverlayManager',
 'visibleGuestApps',
 'showInHostUI',
 'showInHostChanged:',
 'appVisibilityChanged:',
 'restoreDefaults',
 'isCurrentGuest:app',
 'hasPrefix:@"LCFloatingMenu."',
]
missing=[x for x in required if x not in s]
if missing: raise SystemExit('Missing FloatingMenu contract: '+', '.join(missing))
root=Path(sys.argv[1]).parents[1]
if 'LCFloatingReturn.dylib' not in (root/'LCOrbit/Build/build.sh').read_text():
    raise SystemExit('Build output name must be LCFloatingReturn.dylib')
if "'@rpath/LCFloatingReturn.dylib'" not in (root/'LCOrbit/Tests/verify.sh').read_text():
    raise SystemExit('Binary install name must be LCFloatingReturn.dylib')
for removed in ['compatibilityPage:', 'refreshInventoryInBackground', 'switchFromRow:', 'presentAdaptiveDrawer']:
    if removed in s: raise SystemExit('Unexpected legacy menu feature remains: '+removed)
show=s[s.index('- (BOOL)shouldShowOrb {'):]
show=show[:show.index('\n}')+2]
if 'settingsWindow' in show: raise SystemExit('The button must remain visible while Settings is open')
if '[LCOrbitHost isHostUI]' not in show or 'showInHostUI' not in show:
    raise SystemExit('LC host visibility must be explicitly controlled by the setting')
if 'self.showInHostSwitch.on = [[FMPrefs() objectForKey:FMPrefKey(@"showInHostUI")] boolValue]' not in s:
    raise SystemExit('The LC host visibility setting must default to off')
settings=s[s.index('- (void)openSettingsInScene:(UIWindowScene *)scene {'):]

settings=settings[:settings.index('\n}')+2]
if 'visible:NO' in settings: raise SystemExit('Opening Settings must not hide the floating overlay')
if 'win.windowLevel = UIWindowLevelNormal + 70;' not in settings:
    raise SystemExit('Settings window must sit below the floating overlay window')
print('FloatingMenu source contracts: PASS')
PY
