#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/LCFloatingMenu/LCFloatingMenu.m"
# The minimal-return edition deliberately removes the old app drawer, updater,
# compatibility page and task switcher. Validate only the retained contract.
python3 - "$SOURCE" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
required=[
 '@interface FMReturnManager',
 '- (void)installIfPossible',
 '- (void)refreshUI',
 '- (void)returnToLiveContainer',
 '- (void)openSettingsInScene:',
 '- (void)closeSettings',
 'LCFloatingMenuRegisterWithOrbit',
 'LCOrbitOverlayManager',
]
missing=[x for x in required if x not in s]
if missing: raise SystemExit('Missing minimal FloatingMenu contract: '+', '.join(missing))
for removed in ['compatibilityPage:', 'refreshInventoryInBackground', 'switchFromRow:', 'presentAdaptiveDrawer']:
    if removed in s: raise SystemExit('Unexpected legacy menu feature remains: '+removed)
print('Minimal FloatingMenu source contract: PASS')
PY
# Keep tests for the shared runtime/core that remain part of this build.
sh "$ROOT/LCOrbit/Tests/run-core-lifecycle-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-storage-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-storage-status-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-json-log-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-github-access-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-update-release-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-tweak-center-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-multitask-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-task-ownership-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-native-window-registry-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-native-startup-cancellation-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-multitask-hook-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-multitask-parent-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-bootstrap-tests.sh"
sh "$ROOT/LCOrbit/Tests/run-multitask-scene-tests.sh"
