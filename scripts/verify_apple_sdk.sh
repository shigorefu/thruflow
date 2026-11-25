#!/bin/bash
set -euo pipefail

# Fail closed before tests/signing; archive/export validation checks the products too.
xcode_version="$(xcodebuild -version)"
printf '%s\n' "$xcode_version"
if ! [[ "$xcode_version" =~ ^Xcode[[:space:]]27([.][0-9]+)*[[:space:]] ]]; then
  echo 'Xcode 27 is required; do not fall back to an older toolchain.' >&2
  exit 1
fi
for sdk in macosx iphoneos watchos; do
  version="$(xcrun --sdk "$sdk" --show-sdk-version)"
  printf '%s SDK: %s\n' "$sdk" "$version"
  if ! [[ "$version" =~ ^27([.][0-9]+)*$ ]]; then
    echo "Device SDK 27 is required for $sdk." >&2
    exit 1
  fi
done
