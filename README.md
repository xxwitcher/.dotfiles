
These are my dotfiles for Omarchy-Mac. Pick and choose to your liking.
System backups are Asahi Alarm changes. I've maintained the file paths.

Drop a ⭐ if you've found something useful in here.

#### Customizations & Features
##### Gestures & Keybinds
- Swipe between workspaces horizontally. Swipe up/down with 3 fingers to maximize the active window. Swipe up/down with 4 fingers to enter Fullscreen
- Swapped left Command key (SUPER) and Control key & added Left Command + Q for quitting the active window.
  - This means you can now Copy-Paste using left Command + C/V, open new browser tab with Command+T etc. It acts as a Control key.
- Two-finger right click enabled
- Modified app shortcuts (see hypr/bindings.conf)
- SUPER + F10,11,12 for screenshots/recording
##### Look & Feel
- 2K Resolution at 120Hz refresh rate. Scaling set to 1.66.
- Alacritty font size increased to 10.
- No gaps between windows and gradient set to 3 colors (purple->blue->pink). Rounding set to 3.
- Branding updated to ASCII and color set to purple.
- Waybar resized to 30, added spacing between items and battery % always shown. Tooltips now have a tiny border.
##### Functionalities & System Changes
- Auto-hide Waybar and show it only when the cursor is pushed to the very top of the screen.
- Suspend system after 5mins of inactivity
- Suspend system on lid close
- Does not kill user processes on suspend.
- Auto start some apps and arrange them in different workspaces and at different sizes
  - Note: Resizing won't work if you take more than 5 seconds to enter your password on logon after rebooting. The logon screen steals focus and that's needed for automatic resizing.
- Touch bar defaults to media keys, rearranged them and added a screenshot key.
- Emoji picker has a rich list of emojis with the most popular shown at the top. Uses a static local list(emojis.txt) in the .cache folder. emoji-list.txt is an even longer list if you want to add some more emojis to the picker.
##### NeoVim/LazyVim
- Neo-tree opens on the right side and automatically sized at 15% of window width.

