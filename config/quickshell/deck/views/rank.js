// Spotlight ranking, shared by LauncherView.qml and deck/selftest.sh.
// Plain functions and no QML, so the selftest can run this file under node.

// How well `text` matches query `q` (lowercase, trimmed):
// 100 exact, 90 prefix, 75 word start, 70 initials ("vsc"), 50 substring,
// 20 letters in order. 0 means no match.
function match(text, q) {
    if (!text || !q) return 0;
    const t = String(text).toLowerCase();
    if (t === q) return 100;
    if (t.startsWith(q)) return 90;
    const words = t.split(/[\s\-_.:\/]+/).filter(w => w.length > 0);
    if (words.some(w => w.startsWith(q))) return 75;
    if (q.length >= 2 && words.map(w => w[0]).join("").startsWith(q)) return 70;
    if (t.includes(q)) return 50;
    if (q.length >= 3 && inOrder(q, t)) return 20;
    return 0;
}

function inOrder(q, t) {
    let i = 0;
    for (let k = 0; k < t.length && i < q.length; k++)
        if (t[k] === q[i]) i++;
    return i === q.length;
}

// Launch-history boost for an entry [count, lastUsedMs]: up to 30 points,
// halving for every 14 days it goes unused.
function boost(entry, now) {
    if (!entry) return 0;
    const days = Math.max(0, (now - entry[1]) / 86400000);
    return Math.min(30, 12 * Math.log2(1 + entry[0]) * Math.pow(0.5, days / 14));
}

// Whether a query is worth sending to qalc. qalc reads almost any word as a
// unit ("firefox" comes back as 0 B), so only arithmetic, conversions and
// functions get through.
function looksLikeMath(s) {
    s = String(s).trim();
    if (/^(sqrt|sin|cos|tan|log|ln|abs|exp)\b/i.test(s)) return true;
    if (!/\d/.test(s)) return false;
    return /[+\-*\/^%()=]/.test(s)
        || /\b(to|in)\b/i.test(s)
        || /^[\d.,]+\s*[a-z°$€£]+$/i.test(s);
}

// "812 B", "4.2 KB", "31 MB": one decimal only while it adds information.
function fileSize(n) {
    if (!(n >= 0)) return "";
    const units = ["B", "KB", "MB", "GB", "TB"];
    let i = 0;
    while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
    return (i === 0 || n >= 10 ? Math.round(n) : n.toFixed(1)) + " " + units[i];
}
