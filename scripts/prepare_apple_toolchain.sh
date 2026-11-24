#!/bin/bash
set -euo pipefail

if xcrun metal --version; then
  exit 0
fi

xcodebuild -downloadComponent MetalToolchain
xcrun metal --version
