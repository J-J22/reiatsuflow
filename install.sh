#!/bin/sh
# ReiatsuFlow installer: links the CLI and the Quickshell config, creates the data folder,
# builds the tracks and installs the notification timers. Safe to run again.
set -e
repo=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$HOME/.local/bin" "$HOME/.config/quickshell"
ln -sf "$repo/bin/rf" "$HOME/.local/bin/rf"
ln -sfn "$repo/ui" "$HOME/.config/quickshell/reiatsuflow"
echo "linked rf -> ~/.local/bin/rf and ui -> ~/.config/quickshell/reiatsuflow"

"$repo/bin/rf" init          # copies config.example.json to ~/.config/reiatsuflow/config.json if missing
"$repo/bin/rf" timers        # morning + evening notifications from config "notify"

cat <<'EOF'

Done. Start the window with:   qs -c reiatsuflow

Hyprland (Lua config, e.g. ~/.config/hypr/custom/):
  hl.on("hyprland.start", function () hl.exec_cmd("qs -c reiatsuflow") end)
  hl.window_rule({match = {title = "^(ReiatsuFlow)$"}, workspace = "1 silent"})

Hyprland (classic hyprland.conf):
  exec-once = qs -c reiatsuflow
  windowrule = workspace 1 silent, title:^(ReiatsuFlow)$
EOF
