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
 'LCOrbitOverlayManager',
]
missing=[x for x in required if x not in s]
if missing: raise SystemExit('Missing FloatingMenu contract: '+', '.join(missing))
for removed in ['compatibilityPage:', 'refreshInventoryInBackground', 'switchFromRow:', 'presentAdaptiveDrawer']:
    if removed in s: raise SystemExit('Unexpected legacy menu feature remains: '+removed)
print('FloatingMenu source contracts: PASS')
PY
