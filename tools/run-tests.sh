#!/usr/bin/env bash
# Compiles Shared/SharedModels.swift with the standalone logic tests and runs them.
# (Volume math, goal tolerance, streaks, on-disk format compatibility with the widget, and
# review-prompt timing.)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$ROOT/tools/tests/SharedLogicTests.swift" "$TMP/main.swift"
swiftc -O -o "$TMP/run" "$TMP/main.swift" "$ROOT/Shared/SharedModels.swift" "$ROOT/WaterTally/ReviewPrompter.swift" 2>&1 | grep -v "warning:" || true
"$TMP/run"
