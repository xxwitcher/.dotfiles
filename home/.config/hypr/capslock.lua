-- Caps Lock works as a normal Caps Lock. Omarchy makes it the compose key, so
-- that option is taken out of whatever keyboard options are already set and
-- the rest are kept.
local options = hl.get_config("input.kb_options")
options = type(options) == "string" and options or ""

local kept = {}
for option in options:gmatch("[^,]+") do
  if option ~= "compose:caps" then table.insert(kept, option) end
end

local new = table.concat(kept, ",")
if new ~= options then
  hl.config({ input = { kb_options = new } })
end
