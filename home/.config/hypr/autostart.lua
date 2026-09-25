-- Extra autostart processes.
-- o.launch_on_start("my-service")
--
-- Auto-hide the top bar (shows when the cursor touches the top edge).
o.launch_on_start(os.getenv("HOME") .. "/.config/topbar/autohide.sh")
