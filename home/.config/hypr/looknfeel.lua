-- Change the default Omarchy look'n'feel.

-- Border colors: a three-color active gradient (light purple -> purple ->
-- orchid by default) and an inactive color. Pick your own with Setup >
-- Witcher's Tweaks > Configure > Borders, which saves them per machine in
-- ~/.config/witcher-tweaks/border.conf:
--
--   active=c4b5fd a855f7 da70d6
--   inactive=5b3a7a
--
-- The picker previews live by replacing _G.witcher_border, so the spinning
-- gradient below reads the colors from there on every tick.
local function read_border()
  local border = { active = { "c4b5fd", "a855f7", "da70d6" }, inactive = "5b3a7a" }
  local file = io.open(os.getenv("HOME") .. "/.config/witcher-tweaks/border.conf", "r")
  if not file then return border end
  for line in file:lines() do
    local key, value = line:match("^%s*(%w+)%s*=%s*(.-)%s*$")
    if key == "active" then
      local colors = {}
      for hex in value:gmatch("%x%x%x%x%x%x") do colors[#colors + 1] = hex:lower() end
      if #colors == 3 then border.active = colors end
    elseif key == "inactive" and value:match("^%x%x%x%x%x%x$") then
      border.inactive = value:lower()
    end
  end
  file:close()
  return border
end

-- Colors are evenly spaced around the border, so repeating one gives it more
-- of it: 3 parts light, 3 main, 2 accent.
function _G.witcher_border_gradient(border)
  local out, weights = {}, { 3, 3, 2 }
  for i, hex in ipairs(border.active) do
    for _ = 1, weights[i] do out[#out + 1] = "rgba(" .. hex .. "ee)" end
  end
  return out
end

_G.witcher_border = read_border()

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
   general = {
     -- No gaps between windows or borders.
     gaps_in = 0,
     gaps_out = 0,

     -- Gradient window borders (purple unless picked otherwise, see above).
     col = {
       active_border = { colors = _G.witcher_border_gradient(_G.witcher_border), angle = 45 },
       inactive_border = "rgba(" .. _G.witcher_border.inactive .. "aa)",
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

-- Workspaces slide in with a fade (Omarchy switches them instantly), so a
-- swipe or a SUPER+number switch eases over like macOS spaces.
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefade 20%" })

-- Rotate the active border gradient continuously around the window.
-- Hyprland's borderangle "loop" animation stops after one turn on 0.56, so
-- spin the gradient angle from a repeating timer instead.
local border_spin_seconds = 13.33 -- time for one full turn
local border_spin_interval = 33 -- ms between updates (~30fps)

-- One timer for the whole session calls this tick, which every reload
-- redefines, so changes here (and the colors) apply without restarting.
_G.witcher_border_angle = _G.witcher_border_angle or 45
function _G.witcher_border_tick()
  _G.witcher_border_angle = (_G.witcher_border_angle + 360 * border_spin_interval / (border_spin_seconds * 1000)) % 360
  hl.config({ general = { col = { active_border = { colors = _G.witcher_border_gradient(_G.witcher_border), angle = _G.witcher_border_angle } } } })
end

if not _G.witcher_border_timer then
  -- Older versions of this file kept their colors inside their own timer.
  if _G.border_spin_timer then _G.border_spin_timer:set_enabled(false) end
  _G.witcher_border_timer = hl.timer(function() _G.witcher_border_tick() end, { timeout = border_spin_interval, type = "repeat" })
end
