-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use traditional (non-inverse) scrolling.
--       natural_scroll = false,
--
--       -- Re-enable tap-to-click (one-finger tap = left, two-finger = right).
--       tap_to_click = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- Swap Left Ctrl and Left Super (Right Super stays Super, Right Ctrl stays Ctrl).
-- Keep Omarchy's default compose/capslock options, since setting kb_options replaces them.
hl.config({
  input = {
    kb_options = "compose:caps,shift:both_capslock_cancel,ctrl:swap_lwin_lctl",
  },
})

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- macOS-like swipe: a short swipe is enough, and it follows the fingers.
hl.config({
  gestures = {
    workspace_swipe_distance = 150, -- px for a full swipe (default 300); lower responds faster
    workspace_swipe_cancel_ratio = 0.15, -- commit after 15% of the distance instead of 50%
    workspace_swipe_min_speed_to_force = 5, -- a quick flick switches even when short (default 30)
    workspace_swipe_create_new = true, -- swiping past the last workspace makes a new one
    workspace_swipe_forever = true, -- keep going past neighbours in one swipe
  },
})

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })
