pragma Singleton

// The one place the desktop's design lives.
//
// Before this existed, all seven modules carried a byte-identical col() and
// their own FileView on qml_color.json -- nine watchers on one file. That is
// what made the colour-pickup bug so expensive: the onLoadedChanged/onLoaded
// fix had to land in six places and one was missed. Fix it here now.
//
// Colours come from ../qml_color.json, rewritten by hypr/bin/tokyo-palette
// after every wallpaper change. The palette derives its neutrals from the
// wallpaper and clamps the accent into a cyan band; alert and warn are the
// only fixed colours, because colour in this design only ever means "wrong".
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- palette ---------------------------------------------------------
    property var palette: ({})

    function col(key, fallback) {
        const v = root.palette[key];
        return (typeof v === "string" && v.length > 3) ? "#" + v.replace(/^#+/, "") : fallback;
    }

    readonly property color bg:      col("windowBackground", "#0A0A08")
    readonly property color layer1:  col("layerBackground1", "#0F0F0D")
    readonly property color layer2:  col("layerBackground2", "#181814")
    readonly property color layer3:  col("layerBackground3", "#23231D")
    readonly property color text:    col("primaryText",      "#E9EAEC")
    readonly property color dim:     col("secondaryText",    "#6C747F")
    readonly property color line:    col("borderPrimary",    "#2D6376")
    readonly property color line2:   col("borderSecondary",  "#23231D")
    readonly property color accent:  col("accentPrimary",    "#80DAFA")
    readonly property color accent2: col("accentSecondary",  "#39A1C6")
    readonly property color accentDim: col("accentDim",      "#16485A")
    readonly property color onAccent:  col("accentPrimaryText", "#0A0A08")
    readonly property color alert:   col("alert",            "#FF4D5A")
    readonly property color warn:    col("warn",             "#FFB020")
    readonly property color amber:   warn
    readonly property color ok:      col("ok",               "#9ECE6A")
    readonly property color surface: layer2
    readonly property color surfaceElevated: layer3

    // ---- cyberpunk dual-chroma neon & glow -------------------------------
    // Tokyo Night x Cyberpunk high-contrast illuminations
    readonly property color neonCyan:    accent
    readonly property color neonMagenta: col("accentSecondary", "#BB9AF7")
    readonly property color neonYellow:  warn
    readonly property color neonGreen:   ok
    readonly property color neonAlert:   alert

    readonly property color glowCyan:    Qt.rgba(neonCyan.r, neonCyan.g, neonCyan.b, 0.22)
    readonly property color glowMagenta: Qt.rgba(neonMagenta.r, neonMagenta.g, neonMagenta.b, 0.22)
    readonly property color glowAlert:   Qt.rgba(alert.r, alert.g, alert.b, 0.24)

    // ---- apple x cyberpunk: smoked obsidian & photonic glass -------------
    // High-contrast translucent glass depth & laser specular light catch
    readonly property color laser:           accent
    readonly property color laserDim:        accentDim
    readonly property color laserHi:         Qt.tint(accent, "#40FFFFFF")
    readonly property color laserGlow:       Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color specularCatch:   Qt.rgba(accent.r, accent.g, accent.b, 0.45)
    readonly property color specularDim:     Qt.rgba(accent.r, accent.g, accent.b, 0.12)
    readonly property color glassBorder:     Qt.rgba(1.0, 1.0, 1.0, 0.08)

    readonly property color obsidianBase:    bg
    readonly property color glassBg:         Qt.rgba(bg.r, bg.g, bg.b, 0.76)
    readonly property color glassCard:       Qt.rgba(layer1.r, layer1.g, layer1.b, 0.72)
    readonly property color glassElevated:   Qt.rgba(layer2.r, layer2.g, layer2.b, 0.68)
    readonly property color glassActive:     Qt.rgba(accentDim.r, accentDim.g, accentDim.b, 0.50)
    readonly property color glassPressed:    Qt.rgba(accentDim.r, accentDim.g, accentDim.b, 0.70)
    readonly property color laserEdge:       specularCatch
    readonly property color laserEdgeSubtle: specularDim
    readonly property color shadowRim:       Qt.rgba(0.0, 0.0, 0.0, 0.70)
    readonly property color socketBg:        Qt.rgba(layer2.r, layer2.g, layer2.b, 0.55)

    // Micro-typography refinement & Apple typographic hierarchy
    readonly property color textPrimary:     text
    readonly property color textSecondary:   dim
    readonly property color textTertiary:    Qt.rgba(dim.r, dim.g, dim.b, 0.50)
    readonly property real  opacityJP:       0.55
    readonly property int   weightJP:        Font.Light

    // FileView, not a one-shot read: the palette is rewritten under us on
    // every wallpaper change. onLoaded (the signal) and NOT onLoadedChanged
    // (the property handler) -- the latter fires once and never again.
    FileView {
        path: Quickshell.shellDir + "/../qml_color.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.palette = JSON.parse(text()); } catch (e) { root.palette = {}; }
        }
    }

    // ---- type ------------------------------------------------------------
    // Display is a condensed grotesque: it is what makes a dense readout look
    // engineered rather than merely small. Mono carries anything that must
    // not reflow as digits change. JP carries the micro-labels.
    readonly property string fontDisplay: "Barlow Semi Condensed"
    readonly property string fontMono:    "CaskaydiaCove Nerd Font"
    readonly property string fontJP:      "Noto Sans CJK JP"

    // One scale, seven steps. Before this, ten modules improvised eleven
    // different pixel sizes (9 10 11 12 13 14 15 17 22 26 82) and only four
    // of them had names. 11 and 13 fold into szBody, 14 and 17 into szValue.
    readonly property int szNano:    8    // hardware pin tag / protocol chip
    readonly property int szMicro:   9    // EN label + JP micro-label
    readonly property int szTail:    10   // trailing unit / secondary
    readonly property int szBody:    12   // running text, secondary rows
    readonly property int szValue:   15   // the number you actually read
    readonly property int szLead:    20   // section head
    readonly property int szEntry:   26   // one entry in a wheel
    readonly property int szDisplay: 82   // the clock, full-screen surfaces only

    // ---- space -----------------------------------------------------------
    // Unit is 4. Four steps, because a spacing that is not one of these is
    // almost always a number someone nudged until it looked right once.
    readonly property int gap:    4       // inside a row
    readonly property int pad:    12      // inside a component
    readonly property int gutter: 20      // between components
    readonly property int bay:    48      // between regions

    // ---- tracking (Apple Optical Sizing) ---------------------------------
    // A function of scale, not a per-call decision. Condensed faces need air
    // at label size and tight tracking at display size; mono needs none.
    readonly property real trkDisplay: -1.6 // tightened display text
    readonly property real trkBody:     0.0 // natural body copy
    readonly property real trkMicro:    1.6 // airy micro-labels
    readonly property real trkTight:    0.5 // mono values
    readonly property real trkLabel:    1.6 // legacy alias for trkMicro
    readonly property real trkWide:     3.2 // headline tracking

    // ---- motion & fluid spring physics -----------------------------------
    // Apple Fluid Interfaces: motion starts from current value, responds on
    // pointer-down without latency, and settles critically damped (damping: 1.0).
    readonly property real ghost:   0.35  // resting opacity of a stale value
    readonly property int  tapSnapMs: 45  // pointer-down instantaneous tactile snap
    readonly property int  snapMs:  75    // mechanical tactile snap
    readonly property int  decayMs: 2500  // full -> ghost once it goes stale
    readonly property int  holdMs:  3000  // how long a change counts as fresh
    readonly property int  wipeMs:  90    // reveal wipe
    readonly property int  countMs: 380   // digit roll / meter sweep
    readonly property int  easeFastMs: 120 // rapid hover/focus transition
    readonly property int  easeMs:  180   // generic state transition

    // Apple spring characteristics
    readonly property real springDampingDefault:  1.0   // critically damped (zero bounce)
    readonly property real springResponseDefault: 0.32  // 320ms spring response
    readonly property real springDampingFlick:    0.82  // momentum flick bounce
    readonly property real springResponseFlick:   0.28  // 280ms snappy flick

    // ---- semantics -------------------------------------------------------
    // Colour is never decoration here. A screen with no amber and no red on
    // it means nothing is wrong, and that is the only thing colour reports.
    readonly property int threshWarn:  75
    readonly property int threshAlert: 90

    function level(pct) {
        if (pct >= root.threshAlert) return root.alert;
        if (pct >= root.threshWarn)  return root.warn;
        return root.accent;
    }
}
