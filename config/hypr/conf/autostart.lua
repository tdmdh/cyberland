-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE",   theme.cursor_size)
hl.env("HYPRCURSOR_SIZE", theme.cursor_size)

-- https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
    -- swww restores the last wallpaper on its own when the daemon comes up.
    hl.exec_cmd("swww-daemon")
    -- The persistent frame: hairline, corner brackets and the four corner
    -- clusters. Draws only inside gaps_out, on the Bottom layer, so it never
    -- overlaps a window and a fullscreen window hides it entirely.
    hl.exec_cmd("qs -d -c frame")
    -- Scrolling-layout position HUD; shows itself only when it has something
    -- to say (more than one column) and fades back out.
    hl.exec_cmd("qs -d -c hud")
    -- Reactive OSD: disabled in favor of Smart Cyber Island morph
    -- hl.exec_cmd("qs -d -c osd")
    -- Unified Modal Deck Host: Apple fluid spring morphism host for all 15 floating panels
    -- (control, music, cyberpad, keys, agent, clip, todo, sensor, radar, dev, nodemap, expose, palette, schematic, launcher)
    hl.exec_cmd("qs -d -c deck")
    -- Clipboard persistent daemon & watchers
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    -- Automount removable media.
    hl.exec_cmd("udiskie --automount --notify --no-tray")
    -- Notifications: server, popups and history, replacing swaync.
    hl.exec_cmd("qs -d -c notify")
    -- Polkit agent. Nothing was answering polkit before this: polkitd runs,
    -- but no agent was registered, so anything needing a privileged action
    -- hung with no prompt. Replaces hyprpolkitagent, which draws a dialog
    -- with none of this desktop's chrome.
    hl.exec_cmd("qs -d -c auth")
    -- Idle chain. Two processes on purpose: a layer-shell surface and a
    -- WlSessionLock cannot share one Wayland client (the compositor drops the
    -- connection when the lock engages), so `idle` owns the ambient screen and
    -- `lock` owns the session lock. `lock` must be up before `idle` can use it.
    hl.exec_cmd("qs -d -c lock")
    hl.exec_cmd("qs -d -c idle")
end)

-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Needs a full Hyprland restart, not applied on the fly.
-- hl.config({ ecosystem = { enforce_permissions = true } })
-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
