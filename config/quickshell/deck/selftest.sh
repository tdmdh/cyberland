#!/bin/sh
# Selftest for the deck's launcher ranking (views/rank.js).
#   run: ~/.config/quickshell/deck/selftest.sh
set -e
cd "$(dirname "$0")/views"

node -e '
const assert = require("assert");
eval(require("fs").readFileSync("rank.js", "utf8"));

// match tiers
assert.equal(match("Firefox", "firefox"), 100);
assert.equal(match("Firefox", "fir"), 90);
assert.equal(match("Advanced Network Configuration", "net"), 75);
assert.equal(match("Visual Studio Code", "vsc"), 70);
assert.equal(match("Advanced Network Configuration", "fig"), 50);
assert.equal(match("Thunderbird", "tbd"), 20);
assert.equal(match("Firefox", "xyz"), 0);
assert.equal(match("", "a"), 0);
assert.ok(match("Files", "fi") === match("Firefox", "fi"), "prefix ties, history decides");

// history: used beats unused, and it fades
const now = Date.UTC(2026, 0, 30);
assert.equal(boost(undefined, now), 0);
assert.ok(boost([10, now], now) > boost([1, now], now));
// two half-lives: a quarter (count 3 stays under the cap)
assert.ok(Math.abs(boost([3, now - 28 * 86400000], now) - boost([3, now], now) / 4) < 1e-9);
assert.ok(boost([100000, now], now) <= 30);

// only maths reaches qalc
for (const s of ["12*19", "5 km to mi", "sqrt 2", "20%", "(3+4)", "100 usd in eur", "5km"])
    assert.ok(looksLikeMath(s), s);
for (const s of ["firefox", "f1", "2048", "hello world", "code", "gimp2"])
    assert.ok(!looksLikeMath(s), s);

// file sizes
assert.equal(fileSize(812), "812 B");
assert.equal(fileSize(4300), "4.2 KB");
assert.equal(fileSize(31 * 1048576), "31 MB");
assert.equal(fileSize(1024), "1.0 KB");
assert.equal(fileSize(undefined), "");

console.log("deck selftest: ok");
'
