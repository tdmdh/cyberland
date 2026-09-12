-- Shared values. Everything you'd want to tweak in one place.
-- Required as a global `theme` from hyprland.lua, so conf/* can just use it.

-- bin/tokyo-palette rewrites this after every wallpaper change: it takes
-- wallust's raw palette and clamps it into the Tokyo-tech design system, so
-- the accent tracks the wallpaper but never leaves the cyan band. A missing
-- file (never run) yields an empty table and the fallbacks below take over.
local wal = (loadfile(os.getenv("HOME") .. "/.config/hypr/wallust/tokyo.lua")
             or function() return {} end)()

-- Hyprland wants rgb(RRGGBB); the palette is written as #RRGGBB for QML's sake.
local function rgb(hex) return "rgb(" .. (hex:gsub("^#", "")) .. ")" end

local accent   = wal.accentPrimary or "#80FAEB"
local dim      = wal.accentDim     or "#165A52"

return {
    apps = {
        terminal    = "kitty",
        fileManager = "kitty <D-S>-class superfile -e spf",
        browser     = 'xdg-open "https://"',
        notifPanel  = "qs -c notify ipc call notify toggle",
        wallpapers  = "~/Pictures/wallpapers",
    },

    mainMod = "SUPER",

    -- Condensed grotesque for labels, mono for anything numeric. The density
    -- reads as engineered rather than merely small because the two do
    -- different jobs: labels compress, digits hold their column width.
    -- Installed user-local at ~/.local/share/fonts/barlow-semi-condensed.
    fonts = {
        display = "Barlow Semi Condensed",
        ui      = "Inter Display",
        mono    = "CaskaydiaCove Nerd Font",
        jp      = "Noto Sans CJK JP",
    },

    -- The full clamped palette, for anything that wants more than a border.
    palette = wal,

    colors = {
        -- Single flat accent, not a gradient: the look is drawn, not lit.
        active_border   = rgb(accent),
        inactive_border = rgb(dim),
        shadow          = 0xee000000,
        glow            = rgb(accent),
        glow_inactive   = rgb(dim),
    },

    gaps_in   = 4,
    -- The frame draws inside this margin. quickshell's `frame` module is a
    -- click-through overlay with no exclusive zone, so this gap is the only
    -- thing keeping windows off it -- shrink one and they collide.
    --
    -- Top is deep (44) to carry the Smart Dynamic Cyber Island.
    -- The sides and bottom now only carry a hairline (14) since bottom modules
    -- have been unified into the Island. `frame`'s bandBottom matches at 14.
    gaps_out  = { top = 44, right = 14, bottom = 14, left = 14 },
    border    = 1,      -- hairline
    rounding  = 0,

    cursor_size = "24",
}
