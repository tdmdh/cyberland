# Design-system research notes

> **Status, 2026-09-18.** A research record of the codebase as it was when
> written; the platform facts still hold. Since then the launcher stopped being
> its own `launcher/` module and became a deck view (`deck/views/LauncherView.qml`),
> `common/Wheel.qml` was deleted, and Theme's colour aliases were collapsed to one
> name per colour. `Theme.qml`'s comments are the current reference.

No existing `docs/` or notes convention was found under `~/.config/quickshell` or
`~/.config/hypr` (checked with `find ... -iname "*.md"`, zero hits before this
file). Written here per the fallback instruction.

Scope: platform facts only — what Qt 6 QML and Quickshell actually support and
document. No proposal for what Theme.qml should become; that's a separate step.

Files read as context before researching: `common/Theme.qml`, `common/Sys.qml`,
`common/Bracket.qml`, `common/Btn.qml`, `common/Cluster.qml`, `common/Meter.qml`,
`common/Panel.qml`, `common/Standby.qml`, `common/Wheel.qml`, `common/qmldir`,
`launcher/shell.qml`.

---

## 1. Qt 6 QML singletons for design tokens

- Declare a singleton by putting `pragma Singleton` at the top of the QML file.
  Source: https://doc.qt.io/qt-6/qml-singleton.html
- Register it for a directory-based (non-CMake, non-`qt_add_qml_module`) module
  by adding a line to `qmldir`: `singleton MySingleton 1.0 MySingleton.qml`.
  Sources: https://doc.qt.io/qt-6/qml-singleton.html ,
  https://doc.qt.io/qt-6/qtqml-modules-qmldir.html (qmldir spells the keyword
  as `[singleton] Optional. Used to declare a singleton type.`)
- **Bindings on a singleton's own properties are constrained.** Direct wording:
  "Setting up bindings on a singletons properties is not possible; however, if
  it is needed, a Binding element can be used to achieve the same result." And:
  "Care must be taken when installing a binding on a singleton property: If
  done by more than one file, the results are not defined."
  Source: https://doc.qt.io/qt-6/qml-singleton.html
  This is about binding the singleton's *own* properties to something *inside*
  the singleton's declaration (i.e., writing `property int x: someExpression`
  directly as the property's default binding works fine at declaration time —
  the restriction is specifically flagged as needing a `Binding {}` element in
  cases where it "is not possible" per that same doc; the page does not fully
  enumerate which cases those are beyond this warning).
- **Consumers binding to a singleton's properties is supported and normal.**
  From the C++ registration docs: "Q_PROPERTYs of QObject singleton types may
  be bound to." A `readonly property` on a `Singleton { }` root (as Theme.qml
  uses throughout) is a standard Q_PROPERTY-equivalent and any QML file that
  imports the module can bind to it reactively (`color: Theme.accent` etc.) —
  this is exactly the pattern already in use across Theme.qml's consumers, and
  Theme.qml's own `FileView.onLoaded` mutating `root.palette` and having every
  `readonly property color` recompute is standard QML binding re-evaluation,
  not a special singleton behavior.
  Source: https://doc.qt.io/qt-6/qtqml-cppintegration-definetypes.html
- **No associated QQmlContext.** "Singleton types do not have an associated
  QQmlContext as they are shared across all contexts in an engine." Engine
  ownership: "QObject singleton type instances are constructed and owned by
  the QQmlEngine, and will be destroyed when the engine is destroyed." Access
  is by type name, not `id` — singletons are not instantiable from QML.
  Source: https://doc.qt.io/qt-6/qtqml-cppintegration-definetypes.html
- **JS object / array / function members:** the docs do not separately restrict
  exposing a `property var` holding a JS object/array, or a `function` member,
  on a `Singleton`. Theme.qml already does this (`property var palette: ({})`,
  `function col(key, fallback)`, `function level(pct)`) and per the general QML
  property-binding model, a `readonly property` or plain `property var` that
  changes triggers re-evaluation of any binding that reads it — this is
  standard QML change notification, not something the singleton docs call out
  as different for `var`-typed properties. No page found that documents a
  singleton-specific exception for `var`/array/function properties.

## 2. Quickshell's QML import rules

The qmldir comment's claim — "Quickshell blocks '..' in QML imports" — is
**substantially correct but the precise mechanism is scoped to the shell
directory, not to `..` syntax as such**:

- Quickshell 0.2.0 changelog, Breaking Changes: "Files outside of the shell
  directory can no longer be referenced with relative paths, e.g.
  `../../foo.png`." Source: https://quickshell.org/changelog/ (v0.2.0 entry;
  fetched via reader proxy after quickshell.org returned HTTP 403 to direct
  fetches — see note at end of this section).
- The **documented first-party mechanism for sharing QML across a shell** is
  the root-relative import: `import qs.<path>` (or bare `import qs` for the
  shell root). Exact wording: "`qs` can be used to import the shell root
  folder. Dotted paths can be used to access nested subfolders, e.g.
  `qs.foo.bar`." And: "Quickshell module imports are preferable to relative
  path imports as they are much more LSP friendly."
  Source: https://quickshell.org/docs/v0.3.0/guide/qml-language/ (via reader
  proxy, same 403 caveat)
- Ordinary relative subfolder imports still work *within* the shell directory:
  `import "<directory>"` where directory is "the directory to import, relative
  to the current file." Source (older doc snapshot, same content confirmed on
  the qmldir/import basics): https://git.outfoxxed.me/quickshell/quickshell-docs/raw/branch/master/content/docs/configuration/qml-overview.md
- **`Quickshell.shellDir`** is a real, documented property: "The full path to
  the root directory of your shell. The root directory is the folder
  containing the entrypoint to your shell, often referred to as shell.qml."
  It has a companion helper `Quickshell.shellPath(path)` → `${Quickshell.shellDir}/${path}`.
  The older name `shellRoot` is deprecated ("Renamed to shellDir for
  consistency."). Source: https://quickshell.org/docs/v0.3.0/types/Quickshell/Quickshell/
  (via reader proxy). This is exactly what `Theme.qml`'s `FileView` already
  uses: `path: Quickshell.shellDir + "/../qml_color.json"` — note this is
  **string concatenation for a runtime file path**, handed to `FileView`, not
  a QML `import` statement. The v0.2.0 relative-path restriction described
  above is specifically about QML import/reference syntax resolving files
  outside the shell directory; it is not documented as applying to arbitrary
  path strings built at runtime and passed to file-reading types like
  `FileView`. (`Theme.qml`'s existing `../qml_color.json` FileView path is
  not something these docs say is blocked — and empirically it already works
  in this codebase.)
- **On whether the symlink-per-module workaround is "necessary":** the docs
  do not discuss a codebase shaped like this one, where **each of the 9
  modules is its own independent Quickshell entrypoint** (`qs -d -c launcher`,
  `qs -c frame`, etc.), each therefore with its **own, separate `shellDir`**
  (the module's own directory, since that's where each module's `shell.qml`
  lives). Given that `qs.<path>` / `import qs` are documented as resolving
  "relative to the folder shell.qml is in" for the *running* shell instance,
  and given the v0.2.0 restriction on `..` escaping the shell directory, there
  is no documented import syntax that would let `launcher/shell.qml` reach
  `../common` directly — the shell directory for the `launcher` invocation is
  `~/.config/quickshell/launcher/`, and `common/` is a sibling of that, not a
  descendant. **This is inference from the documented rules above, not a
  directly-stated verdict from the docs** (no page discusses the specific case
  of several sibling shell roots wanting one shared components directory). The
  symlink (`common -> ../common`) makes `common/` a *child* of each module's
  shell directory, which sidesteps the restriction entirely and lets
  `import "./common"` (as `launcher/shell.qml` does) or `import qs.common`
  both work. No first-party "extra search path" flag (e.g., a `QML_IMPORT_PATH`-
  style setting) was found documented for Quickshell itself; ordinary Qt
  `QML_IMPORT_PATH`/`QML2_IMPORT_PATH` environment variables are a Qt-wide
  mechanism (see https://doc.qt.io/qt-6/qtqml-syntax-imports.html) but nothing
  in the Quickshell docs found ties shell-root resolution to them.
- **403 caveat:** `quickshell.org` returns HTTP 403 to this environment's
  direct `WebFetch` (both `/docs/` and `/changelog/`, across several path/
  version combinations tried). The quotes above from quickshell.org were
  retrieved via a read-only reader proxy (`r.jina.ai`) mirroring the same
  live pages — content, not interpretation. Treat the quickshell.org URLs
  above as the citation; the proxy was only a transport workaround.

## 3. Font metrics in Qt Quick `Text`

- **`font.letterSpacing` is in pixels**, and is an absolute offset, not scaled
  by point size. Exact wording: "Letter spacing changes the default spacing
  between individual letters in the font. A positive value increases the
  letter spacing by the corresponding pixels; a negative value decreases the
  spacing." No documented interaction with `font.pixelSize` beyond both being
  independent absolute-pixel settings — a fixed `letterSpacing: 5` reads as
  proportionally *tighter* at a large `pixelSize` and *looser* at a small one,
  but the docs state this only implicitly (by defining spacing as a flat pixel
  add-on, not a per-em value). Source: https://doc.qt.io/qt-6/qml-qtquick-text.html
- **`font.capitalization`** enum values, verbatim: `Font.MixedCase` ("the
  normal case: no capitalization change is applied"), `Font.AllUppercase`,
  `Font.AllLowercase`, `Font.SmallCaps`, `Font.Capitalize` ("first character of
  each word as an uppercase character"). Source: same page.
- **`font.weight`** accepts "an integer between 1 and 1000, or one of the
  predefined values" (Thin=100 … Black=900). Source: same page.
- **Weight fallback when the family lacks that exact weight:** Qt Quick's own
  page doesn't spell out the fallback, but the underlying `QFont` matching
  algorithm does: family is "the dominant search criteria," and once a family
  is chosen, remaining attributes (fixedPitch, pointSize, weight, style) are
  matched in priority order, falling back to "the closest matching installed
  font" — i.e., an unavailable weight resolves to the closest weight the
  family actually ships, not to a hard failure or silently ignored request.
  Source: https://doc.qt.io/qt-6/qfont.html
- **`Text.elide` + `width`:** "Set this property to elide parts of the text
  fit to the Text item's width. The text will only elide if an explicit width
  has been set" — i.e. `elide` is a no-op without an explicit `width`.
  Source: https://doc.qt.io/qt-6/qml-qtquick-text.html
- **`FontMetrics`** — read-only, font-derived measurements (`ascent`,
  `descent`, `height`, `lineSpacing`, `averageCharacterWidth`,
  `maximumCharacterWidth`) plus methods (`advanceWidth(text)`,
  `boundingRect(text)`, `elidedText()`). Documented as wrapping "a subset of
  the C++ QFontMetricsF API," and the reference page's own example computes a
  layout size directly from it (`width: fontMetrics.height * 4`) — so yes,
  it's usable to derive a runtime type/spacing scale (e.g. sizing something
  off a base font's measured line height) rather than hardcoding pixel values.
  Source: https://doc.qt.io/qt-6/qml-qtquick-fontmetrics.html
- **`TextMetrics`** — same idea, scoped to a specific string: `width`/`height`
  of the string's bounding rect, `advanceWidth`, `boundingRect`/
  `tightBoundingRect`, plus `elide`/`elideWidth`/`elidedText` for measuring an
  elided result before rendering it. Source:
  https://doc.qt.io/qt-6/qml-qtquick-textmetrics.html

## 4. Qt Quick motion primitives

- **`Behavior on <prop>`**: "defines the default animation to be applied
  whenever a particular property value changes." `enabled` (default true)
  "holds whether the behavior will be triggered when the tracked property
  changes value" — set false to suppress. If a `State`'s `Transition` also
  targets the same property, "the Transition animation overrides the Behavior
  for that state change." One `Behavior` per property, but it can wrap a
  `ParallelAnimation`/`SequentialAnimation` to run more than one animation.
  Source: https://doc.qt.io/qt-6/qml-qtquick-behavior.html
- **`easing.type` values** available to `NumberAnimation`/`PropertyAnimation`
  (a non-exhaustive list matching what's documented): `Easing.Linear`; the
  Quad/Cubic/Quart/Quint families each with In/Out/InOut/OutIn variants;
  Sine, Expo, Circ families likewise; `Easing.InElastic`/`OutElastic`/etc.
  ("exponentially decaying sine wave," tunable via `amplitude`/`period`);
  `Easing.InBack`/`OutBack`/etc. ("overshooting cubic function," tunable via
  `overshoot`); `Easing.InBounce`/`OutBounce`/etc. ("exponentially decaying
  parabolic bounce"); and `Easing.BezierSpline` ("Custom easing curve defined
  by the easing.bezierCurve property"). `Theme.qml`'s and `Cluster.qml`'s use
  of `Easing.OutCubic` is one of these documented standard curves, not a
  custom one. Source: https://doc.qt.io/qt-6/qml-qtquick-propertyanimation.html
- **`PathView.pathItemCount`**: "the number of items visible on the path at
  any one time" (undefined = show all). Source:
  https://doc.qt.io/qt-6/qml-qtquick-pathview.html
- **`preferredHighlightBegin`/`preferredHighlightEnd`**: "set the preferred
  range of the highlight (current item) within the view," each in `[0,1]`,
  with `End >= Begin` required. Combined with `highlightRangeMode:
  PathView.StrictlyEnforceRange` (used in `Wheel.qml`), "the highlight will
  never move outside of the range" — this is what pins the current item at a
  fixed fractional position on the path (Wheel.qml sets both to `0.5`, i.e.
  the selected item is locked at the path's midpoint). The other two modes,
  for contrast: `NoHighlightRange` ("moves freely"), `ApplyRange` ("will
  attempt to maintain... however can move outside... at the ends of the path
  or due to mouse interaction"). Source: same page.
- **`PathAttribute` interpolation**: "The PathAttribute object allows
  attributes consisting of a name and a value to be specified for various
  points along a path... The value of an attribute at any particular point
  along the path is interpolated from the PathAttributes bounding that
  point." Each named attribute becomes an attached property on the delegate
  as `PathView.<name>` (documented example: an attribute named
  `itemRotation` going 0→90 along the path is read in the delegate as
  `rotation: PathView.itemRotation`, and a point midway along the path gets
  ≈45). This is exactly the mechanism `Wheel.qml` uses for `iScale`/
  `iOpacity` — three `PathAttribute` pairs (start/mid/end) per name, and the
  delegate reading `PathView.iScale ?? 0.45` / `PathView.iOpacity ?? 0.12`
  gets values Qt itself interpolates along each `PathQuad` segment; the `??`
  fallback exists for the moment the attached property doesn't resolve, not
  because Qt leaves gaps in the interpolation.
  Source: https://doc.qt.io/qt-6/qml-qtquick-pathattribute.html

## 5. First-party Qt guidance on scalable design tokens

- **QtQuick.Controls styling docs do not document a spacing/type-scale
  convention.** The customization guide is about overriding *individual*
  controls' visual delegates and building a *style directory* of QML files;
  it does not prescribe or even mention a token scale (spacing units, type
  ramp, etc.). The only tangential idea present is *attached properties* as a
  way to hang extra style-wide values off items without touching existing
  types — presented as a pattern, not a built-in system.
  Source: https://doc.qt.io/qt-6/qtquickcontrols-customize.html
- **`Qt.application.font`** exists (confirmed: it's one of the properties
  that goes undefined "when using QML without a QGuiApplication," implying
  it's populated when one exists) but the fetched reference page for the
  global `Qt` object does not further document it as a design-token
  mechanism — no guidance on binding component fonts to it as a convention.
  Source: https://doc.qt.io/qt-6/qml-qtqml-qt.html
- A `Palette` QML type (`QtQuick.Controls` / `QtQuick.Window`, for
  palette propagation through Controls) is referenced in Qt's own
  changelogs/type index, but the specific reference page attempted
  (`qml-qtquick-controls-palette.html`) 404'd in this environment, so its
  documented behavior is **not verified here** — see Unverified section.
- **Plain conclusion: Qt does not document a first-party "design token" or
  spacing/type-scale convention for QML.** What it documents instead are
  low-level primitives (`FontMetrics`/`TextMetrics` for measuring, singletons
  for centralizing values, `Behavior`/`PropertyAnimation` for motion) that a
  project can use to *build* such a scale, plus, for `QtQuick.Controls`
  specifically, built-in styles (Material, Universal, etc.) that carry their
  own internal theming — but that's app-wide Controls theming, not a
  general-purpose QML design-token API applicable to a `PanelWindow`/
  `ShellRoot`-based Quickshell config like this one.

## Unverified / could not confirm

- **`QtQuick.Controls` `Palette` type's exact documented behavior** — the
  `qml-qtquick-controls-palette.html` reference page returned HTTP 404 in
  this environment; not re-attempted at an alternate URL. Not used by this
  codebase anyway (no `QtQuick.Controls` import appears in the files read).
- **Exact fallback rule for `font.weight` inside `QtQuick`'s own docs** (as
  opposed to the underlying `QFont`/`QFontInfo` C++ layer) — the Qt Quick
  `Text`/font-group page states the accepted range and named constants but
  does not itself restate the fallback-matching algorithm; that had to be
  sourced from the C++ `QFont` docs instead (cited above) and is reasonable
  to assume applies, but is not restated verbatim on the QML-specific page.
  Source checked: https://doc.qt.io/qt-6/qml-qtquick-text.html ; fallback
  source used instead: https://doc.qt.io/qt-6/qfont.html
- **Whether the specific interaction of `font.letterSpacing` with very large
  `font.pixelSize`, or any documented scaling/em-relative mode, exists** — no
  page found documenting `letterSpacing` as anything other than a flat pixel
  constant; no em/percentage mode is documented for it in Qt 6 QML.
- **A definitive, first-party statement that the `common -> ../common`
  symlink workaround is "necessary"** — this is a reasoned inference from
  documented shell-directory scoping and the v0.2.0 relative-path
  restriction (see section 2), not something any fetched page states outright
  for a multi-entrypoint layout like this one's 9 independent `shell.qml`
  roots. No Quickshell doc page discusses sharing code between sibling shell
  roots specifically.
- **`quickshell.org` direct fetch access**: every direct `WebFetch` to
  `quickshell.org/docs/*` and `quickshell.org/changelog/` returned HTTP 403 in
  this environment regardless of version path tried (`v0.1.0`, `v0.2.1`,
  `v0.3.0`). All quickshell.org citations above were retrieved through a
  read-only reader-proxy fetch of the same live URLs (not through Google
  cache, not through a mirror/fork) — the citation URLs are the canonical
  quickshell.org pages; the proxy was purely a transport-layer workaround for
  this environment's fetch tool being blocked, not a different source.
