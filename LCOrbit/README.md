# LCOrbit build support

This directory contains the minimal Orbit runtime sources required to package `LCFloatingReturn.dylib` as a standalone arm64 iOS tweak.

Build on macOS with Xcode:

```sh
LCOrbit/Build/build.sh dist/LCFloatingReturn.dylib
LCOrbit/Tests/verify.sh dist/LCFloatingReturn.dylib
```

The binary is compiled and verified by the `Build LCFloatingReturn dylib` GitHub Actions workflow. Runtime behavior must be tested on a signed LiveContainer / SideStore installation.
