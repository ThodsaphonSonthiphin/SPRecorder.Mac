#!/bin/sh
# Fails the SPRecorderCore build when a Core source imports a platform framework.
# The Swift compiler does not enforce this (sprecorder-mac-0002 correction); this does
# (sprecorder-mac-0007). Runs as the first build phase of the SPRecorderCore target.
if grep -rlE '^import (AppKit|SwiftUI|ScreenCaptureKit|AVFoundation|Carbon|CoreAudio)' "$SRCROOT/SPRecorderCore"; then
  echo "error: SPRecorderCore must not import a platform framework (sprecorder-mac-0002)"
  exit 1
fi
