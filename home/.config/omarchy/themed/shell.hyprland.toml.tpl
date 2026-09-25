# Merged over the [hyprland] section of every theme's generated shell.toml.
# Bar popups, notifications, the lock screen and password prompts use
# active-border, so this gives them the same gradient as Hyprland's active
# window border. Keep it in sync with border_colors in hypr/looknfeel.lua.
[hyprland]
active-border            = "rgba(c4b5fdee) rgba(c4b5fdee) rgba(c4b5fdee) rgba(a855f7ee) rgba(a855f7ee) rgba(a855f7ee) rgba(da70d6ee) rgba(da70d6ee) 45deg"
active-border-foreground = "{{ shell_gradient hyprland_active_border foreground }}"
