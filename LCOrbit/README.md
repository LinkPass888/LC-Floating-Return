# LCOrbit build support

This directory contains the minimal Orbit runtime sources required to package `LCFloatingMenu.dylib` as a standalone arm64 iOS tweak.

Build on macOS with Xcode:

```sh
LCOrbit/Build/build.sh dist/LCFloatingMenu.dylib
LCOrbit/Tests/verify.sh dist/LCFloatingMenu.dylib
```

The binary is compiled and verified by the `Build LCFloatingMenu dylib` GitHub Actions workflow. Runtime behavior must be tested on a signed LiveContainer / SideStore installation.
