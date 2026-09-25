-- Change the default Omarchy look'n'feel.

-- Active border gradient: light purple -> purple -> orchid. Colors are evenly
-- spaced, so repeat a color to give it more of the border.
local border_colors = { "rgba(c4b5fdee)", "rgba(c4b5fdee)", "rgba(c4b5fdee)", "rgba(a855f7ee)", "rgba(a855f7ee)", "rgba(a855f7ee)", "rgba(da70d6ee)", "rgba(da70d6ee)" }

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
   general = {
     -- No gaps between windows or borders.
     gaps_in = 0,
     gaps_out = 0,

     -- Purple window borders.
     col = {
       active_border = { colors = border_colors, angle = 45 },
       inactive_border = "rgba(5b3a7aaa)",
     },
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
   },
 })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
 hl.config({
   scrolling = {
     -- See only one column per screen instead of two.
     column_width = 0.97,
   },
 })

-- Rotate the active border gradient continuously around the window.
-- Hyprland's borderangle "loop" animation stops after one turn on 0.56, so
-- spin the gradient angle from a repeating timer instead.
local border_spin_seconds = 13.33 -- time for one full turn
local border_spin_interval = 33 -- ms between updates (~30fps)
local border_angle = 45

if not _G.border_spin_timer then
  _G.border_spin_timer = hl.timer(function()
    border_angle = (border_angle + 360 * border_spin_interval / (border_spin_seconds * 1000)) % 360
    hl.config({ general = { col = { active_border = { colors = border_colors, angle = border_angle } } } })
  end, { timeout = border_spin_interval, type = "repeat" })
end
