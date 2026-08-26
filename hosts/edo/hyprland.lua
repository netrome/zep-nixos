-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- Hyprland reapplies these on hotplug, so no kanshi is needed; a second daemon
-- would only race this one for control of the outputs.
--
-- Catch-all first — later rules override it, so anything unknown still lights up.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Home desk: 34" ultrawide to the LEFT of the laptop.
--
-- Matched on description rather than "DP-3" because connector numbering can
-- change between plug-ins; the description is stable per physical monitor.
--
-- 50Hz is the ceiling at native resolution over the current cable: the mode
-- list (4K capped at 30, 3440x1440 capped at 50, 1080p up to 120) is the
-- signature of a bandwidth-limited link, most likely USB-C DP alt mode
-- negotiating 2 lanes instead of 4. The panel itself does 144Hz. If a
-- different cable or port ever gives 4 lanes, raise this — 3440x1440@100 and
-- above should then appear in `hyprctl monitors all`.
hl.monitor({
    output   = "desc:Microstep MSI MAG342CQR DB6H261C02870",
    mode     = "3440x1440@50",
    position = "0x0",
    scale    = 1,
})

-- Laptop panel to the right of it. y=440 bottom-aligns the two (the ultrawide
-- is 1440 tall, this panel is 1600/1.6 = 1000 logical), which matches how they
-- physically sit on the desk. Use y=0 to top-align instead.
hl.monitor({
    output   = "eDP-1",
    mode     = "2560x1600@240",
    position = "3440x440",
    scale    = 1.6,
})


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "alacritty"
local fileManager = "dolphin"
local menu        = "fuzzel"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
-- hl.on("hyprland.start", function () 
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
-- end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Theme name must be set here too, not just in home-manager: the compositor
-- reads it at startup, before any session variables from the shell profile.
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(

        -- Escape hatch, not a convenience. If DPMS ever ends up off while the
        -- session is otherwise alive, these make any keypress or mouse move
        -- bring the panels back. Without them the only recovery is a blind
        -- reboot, because a dark screen is indistinguishable from a hung one.
        key_press_enables_dpms   = true,
        mouse_move_enables_dpms  = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "se",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

-- This section deliberately does NOT follow Hyprland's example config, which
-- is an arbitrary starting point rather than a convention (Super+Q for a
-- terminal, Super+M to quit with no confirmation). It follows i3/sway instead:
-- that vocabulary is what Regolith is built on, what most tiling-WM cheat
-- sheets assume, and it is internally consistent — Shift moves whatever the
-- unshifted key focuses.
--
-- Every bind carries a description, so `hyprctl binds` prints a cheat sheet of
-- exactly what is live. That is the authoritative list; this file is the source.

local mod = "SUPER" -- Sets "Windows" key as main modifier

local function bind(keys, dispatcher, desc, opts)
    opts = opts or {}
    opts.description = desc
    return hl.bind(keys, dispatcher, opts)
end

-- Direction table drives focus, move and resize so the three stay in sync.
-- Both hjkl and the arrow keys are bound; there is no cost to having both.
--
-- `mon` is the monitor selector for the same direction. It is deliberately a
-- single letter: a monitor selector only accepts l/r/u/d/t/b as a direction
-- (isDirection() in helpers/MiscFunctions.cpp), and anything longer falls
-- through to being matched as a monitor *name* — which silently does nothing
-- at dispatch time, since `hyprctl eval` only builds the closure and cannot
-- catch it.
local dirs = {
    { key = "H", arrow = "left",  dir = "left",  mon = "l", dx = -1, dy =  0 },
    { key = "J", arrow = "down",  dir = "down",  mon = "d", dx =  0, dy =  1 },
    { key = "K", arrow = "up",    dir = "up",    mon = "u", dx =  0, dy = -1 },
    { key = "L", arrow = "right", dir = "right", mon = "r", dx =  1, dy =  0 },
}

---- Launching ----
bind(mod .. " + Return", hl.dsp.exec_cmd(terminal),    "Open terminal")
bind(mod .. " + Space",  hl.dsp.exec_cmd(menu),        "Application launcher")
bind(mod .. " + D",      hl.dsp.exec_cmd(menu),        "Application launcher (alias)")
bind(mod .. " + E",      hl.dsp.exec_cmd(fileManager), "Open file manager")

---- Window management ----
bind(mod .. " + SHIFT + Q",     hl.dsp.window.close(),                            "Close window")
bind(mod .. " + F",             hl.dsp.window.fullscreen(),                       "Fullscreen")
bind(mod .. " + SHIFT + F",     hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximize (keeps gaps)")
bind(mod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }),       "Toggle floating")
bind(mod .. " + C",             hl.dsp.window.center(),                           "Center floating window")
bind(mod .. " + V",             hl.dsp.layout("togglesplit"),                     "Toggle split direction")
bind(mod .. " + P",             hl.dsp.window.pseudo(),                           "Toggle pseudo-tiling")

---- Focus and movement ----
-- Plain focus already crosses monitors at the edge of the layout, so there is
-- no separate "focus monitor" bind. Ctrl+Shift is i3's convention for taking
-- the whole workspace to the next output (`move workspace to output <dir>`),
-- and focus follows it there.
for _, d in ipairs(dirs) do
    for _, k in ipairs({ d.key, d.arrow }) do
        bind(mod .. " + " .. k,                hl.dsp.focus({ direction = d.dir }),       "Focus " .. d.dir)
        bind(mod .. " + SHIFT + " .. k,        hl.dsp.window.move({ direction = d.dir }), "Move window " .. d.dir)
        bind(mod .. " + CTRL + SHIFT + " .. k, hl.dsp.workspace.move({ monitor = d.mon }), "Move workspace to monitor " .. d.dir)
    end
end

---- Resize mode (i3's Super+R submap; Escape or Enter leaves it) ----
local RESIZE_STEP = 60

hl.define_submap("resize", "escape", function()
    for _, d in ipairs(dirs) do
        for _, k in ipairs({ d.key, d.arrow }) do
            -- relative defaults to *false*, unlike legacy `resizeactive`: without
            -- it a step is read as an exact target size and rejected as invalid.
            hl.bind(k, hl.dsp.window.resize({ x = d.dx * RESIZE_STEP, y = d.dy * RESIZE_STEP, relative = true }),
                { repeating = true })
        end
    end
    hl.bind("Return", hl.dsp.submap("reset"))
end)

bind(mod .. " + R", hl.dsp.submap("resize"), "Resize mode (hjkl/arrows, Esc or Enter to exit)")

---- Workspaces ----
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }),       "Switch to workspace " .. i)
    bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), "Move window to workspace " .. i)
end

bind(mod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }), "Next workspace")
bind(mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")

-- Scratchpad on minus, which is i3's actual convention ($mod+minus /
-- $mod+Shift+minus). It was on S, but that is where slackmd lives.
bind(mod .. " + minus",         hl.dsp.workspace.toggle_special("magic"),            "Toggle scratchpad")
bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:magic" }), "Move window to scratchpad")

---- Session ----
-- Via loginctl rather than hyprlock directly: hypridle catches the logind Lock
-- signal and runs the locker, which keeps logind's LockedHint accurate.
bind(mod .. " + Escape",    hl.dsp.exec_cmd("loginctl lock-session"), "Lock screen")
bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"), "Reload config")
-- Guarded: nothing session-ending should be one unconfirmed keypress away.
-- The physical power key lands here too; logind ignores its short press.
bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("power-menu"), "Power menu")
bind("XF86PowerOff",        hl.dsp.exec_cmd("power-menu"), "Power menu")

---- Own tools ----
-- slackmd converts the clipboard in place, so these are fire-and-forget: copy
-- in Slack, hit Super+M, paste as Markdown (and the reverse with Super+S).
bind(mod .. " + M",         hl.dsp.exec_cmd("slackmd to-md"),    "Clipboard: Slack to Markdown")
bind(mod .. " + S",         hl.dsp.exec_cmd("slackmd to-slack"), "Clipboard: Markdown to Slack")
bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("mojime"),           "Emoji picker")

---- Notifications ----
bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("makoctl mode -t do-not-disturb"), "Toggle do-not-disturb")
bind(mod .. " + N",         hl.dsp.exec_cmd("makoctl dismiss --all"),           "Dismiss all notifications")

---- Screenshots ----
-- Print-key based, as on Regolith. Unmodified Print is the common case
-- (grab a region, paste it somewhere); Ctrl additionally writes a file.
bind("Print",                hl.dsp.exec_cmd("screenshot region"),      "Screenshot: region to clipboard")
bind("SHIFT + Print",        hl.dsp.exec_cmd("screenshot output"),      "Screenshot: whole screen to clipboard")
bind("ALT + Print",          hl.dsp.exec_cmd("screenshot window"),      "Screenshot: active window to clipboard")
bind("CTRL + Print",         hl.dsp.exec_cmd("screenshot region save"), "Screenshot: region to file")
bind("CTRL + SHIFT + Print", hl.dsp.exec_cmd("screenshot output save"), "Screenshot: whole screen to file")

---- Mouse ----
-- Scroll through existing workspaces with mod + scroll
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next workspace")
bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")

-- Move/resize windows with mod + LMB/RMB and dragging
bind(mod .. " + mouse:272", hl.dsp.window.drag(),   "Drag window",   { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Mojime is a transient picker, not a tiled window. Two rules because the
-- Wayland app_id and the window title are set independently — the title is
-- "Mojime" (set via ViewportBuilder), the app_id comes from the binary name.
hl.window_rule({
    name   = "float-mojime-class",
    match  = { class = "^(mojime|Mojime)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "float-mojime-title",
    match  = { title = "^Mojime$" },
    float  = true,
    center = true,
})
