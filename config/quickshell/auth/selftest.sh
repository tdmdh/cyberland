#!/bin/sh
# Selftest for the auth card's sudo door (hypr/bin/qs-askpass + sudo-shim).
#
# Never gives real sudo a password: three rejected attempts trip pam_faillock
# and lock the account. Everything here uses `sudo -n`, which cannot
# authenticate, or a request with no sudo behind it.
#
# Step 3 pops the card for a moment, which takes the keyboard while it is up.
#   run: ~/.config/quickshell/auth/selftest.sh
set -u

QS=~/.config/quickshell
BIN=~/.config/hypr/bin
fail() { echo "FAIL: $1" >&2; exit 1; }
status() { qs -c auth ipc call auth status 2>/dev/null; }

# 1. The card is up and speaks the askpass contract.
status | grep -q '"registered":true' || fail "auth card not registered as polkit agent"
status | grep -q '"asks":'           || fail "auth card has no askpass queue (old build running?)"

# 2. The shim adds -A normally, and not alongside -S (a sudo usage error).
out=$("$BIN/sudo-shim/sudo" -n true 2>&1)
echo "$out" | grep -qi usage && fail "shim broke plain sudo -n: $out"
out=$(echo | "$BIN/sudo-shim/sudo" -S -n true 2>&1)
echo "$out" | grep -qi usage && fail "shim passed -A alongside -S: $out"

# 3. A request reaches the card, and a helper that gives up takes it back off.
before=$(ls -d "${XDG_RUNTIME_DIR:-/tmp}"/qs-askpass.* 2>/dev/null | wc -l)
"$BIN/qs-askpass" "[sudo] password for selftest: " >/dev/null 2>&1 &
H=$!
i=0; until status | grep -q '"asks":1'; do i=$((i+1)); [ $i -gt 25 ] && break; sleep 0.2; done
status | grep -q '"asks":1' || { kill $H 2>/dev/null; fail "request never reached the card"; }
kill -TERM $H; wait $H 2>/dev/null
i=0; until status | grep -q '"asks":0'; do i=$((i+1)); [ $i -gt 25 ] && break; sleep 0.2; done
status | grep -q '"asks":0' || fail "a dead helper left its request on the card"
after=$(ls -d "${XDG_RUNTIME_DIR:-/tmp}"/qs-askpass.* 2>/dev/null | wc -l)
[ "$after" -le "$before" ] || fail "helper left its FIFO dir behind"

# 4. The card's writer, the exact command from shell.qml, not a copy of it.
WRITER=$(sed -n "s/.*\"sh\", \"-c\", '\(.*\)', \"sh\", fifo.*/\1/p" "$QS/auth/shell.qml")
[ -n "$WRITER" ] || fail "could not find the writer command in auth/shell.qml"
d=$(mktemp -d)
# A vanished FIFO must not turn into a regular file holding the secret.
printf 'x' | timeout 5 sh -c "$WRITER" sh "$d/fifo"
[ -e "$d/fifo" ] && { rm -rf "$d"; fail "writer created a file where the FIFO was"; }
# A live FIFO receives exactly what was written.
mkfifo "$d/fifo"; cat "$d/fifo" > "$d/got" & R=$!
printf 's3cret\n' | timeout 5 sh -c "$WRITER" sh "$d/fifo"
wait $R
got=$(cat "$d/got"); rm -rf "$d"
[ "$got" = "s3cret" ] || fail "FIFO handoff lost the answer (got '$got')"

echo "auth selftest: ok"
