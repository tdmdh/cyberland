#!/bin/sh
# Selftest for the frame module (Smart Dynamic Cyber Island).
#
# Asserts the module loads clean and that the island's animation gating holds.
#
# The gating matters because of one measured fact: on this island, zero running
# animations costs 0.00% CPU and *any* running animation costs 1-2%, near enough
# regardless of how many. An animation on a row faded to opacity 0 draws nothing
# and still bills full price, so the `running:` gates are the only thing keeping
# idle modes free -- and nothing about the UI looks wrong when one goes missing.
#   run: ~/.config/quickshell/frame/selftest.sh
set -e

QS=~/.config/quickshell
fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. Every infinite animation in the island is gated on something.
UNGATED=$(grep -B3 'loops: Animation.Infinite' "$QS/frame/shell.qml" \
          | grep -c 'running: true' || true)
[ "$UNGATED" = "0" ] || fail "$UNGATED infinite animation(s) hardcoded running: true"

grep -q 'running: pip.running' "$QS/common/Pip.qml" || fail "Pip lost its running gate"
grep -q '^Pip 1.0 Pip.qml$'     "$QS/common/qmldir" || fail "Pip not registered in qmldir"
grep -q '^Readout 1.0 Readout.qml$' "$QS/common/qmldir" || fail "Readout not registered in qmldir"

# 1b. The island is the only part of the frame that takes input. An empty mask
# here is silent: the island simply stops responding and still looks right.
grep -q 'mask: Region { item: hoverZone }' "$QS/frame/shell.qml" \
  || fail "island input mask is gone -- hover and click are dead"

# 1c. Resting is the all-day mode. Anything looping in it holds the compositor
# at full rate forever -- 8% GPU against 33% when one 4px square breathed.
# Transient modes may animate; this one may not.
RESTING=$(sed -n '/6. RESTING STATE/,/7. THRESHOLD SENTINELS/p' "$QS/frame/shell.qml")
echo "$RESTING" | grep -q 'Animation.Infinite' \
  && fail "resting mode animates again -- that is ~25 points of GPU, all day"

# 2. The module actually loads -- catches a broken Pip wiring or QML syntax.
LOG=$(mktemp)
qs -d -c frame >"$LOG" 2>&1
sleep 3
grep -q 'Configuration Loaded' "$LOG" || { cat "$LOG" >&2; fail "frame did not load"; }
grep -qiE 'error|warning|is not a type|Cannot assign' "$LOG" && { cat "$LOG" >&2; fail "QML diagnostics on load"; }

# pgrep -f would also match this script's own command line.
RUNNING=0
for p in $(pgrep -x qs); do
    tr '\0' ' ' < "/proc/$p/cmdline" | grep -q -- '-c frame' && RUNNING=1
done
[ "$RUNNING" = "1" ] || fail "frame daemon not running after launch"

rm -f "$LOG"
echo "frame selftest: ok"
