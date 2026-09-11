#!/bin/sh
# Fails the SPRecorderCore build when a Core source imports anything but Foundation (sprecorder-mac-0002).
# The Swift compiler does not enforce this; this does (sprecorder-mac-0007). It is an allowlist, so
# `@preconcurrency import`, `public import` and frameworks nobody thought to list are caught too.
# Runs as the first build phase of the SPRecorderCore target.
if grep -rnE '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*((public|package|internal|fileprivate|private)[[:space:]]+)?import[[:space:]]' "$SRCROOT/SPRecorderCore" \
   | grep -vE 'import[[:space:]]+((struct|class|enum|protocol|func|var|let|typealias)[[:space:]]+)?Foundation(\.|[[:space:]]|$)'; then
  echo "error: SPRecorderCore imports only Foundation (sprecorder-mac-0002)"
  exit 1
fi
