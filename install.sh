#!/bin/sh
# ReiatsuFlow installer: links the CLI and the Quickshell config, creates the data folder,
# builds the tracks and installs the notification timers. Safe to run again.
set -e
repo=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$HOME/.local/bin" "$HOME/.config/quickshell"
ln -sf "$repo/bin/rf" "$HOME/.local/bin/rf"
ln -sf "$repo/bin/reiatsuflow" "$HOME/.local/bin/reiatsuflow"
ln -sfn "$repo/ui" "$HOME/.config/quickshell/reiatsuflow"
echo "linked rf, reiatsuflow -> ~/.local/bin and ui -> ~/.config/quickshell/reiatsuflow"

# app launcher entry + icon
apps="$HOME/.local/share/applications"; icons="$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$apps" "$icons"
cp "$repo/data-files/reiatsuflow.svg" "$icons/reiatsuflow.svg"
sed -e "s|@BIN@|$HOME/.local/bin|g" -e "s|@ICON@|reiatsuflow|g" "$repo/data-files/reiatsuflow.desktop.in" > "$apps/reiatsuflow.desktop"
update-desktop-database "$apps" 2>/dev/null || true
echo "added ReiatsuFlow to the app launcher"

"$repo/bin/rf" init          # copies config.example.json to ~/.config/reiatsuflow/config.json if missing
"$repo/bin/rf" timers        # morning + evening notifications from config "notify"

cat <<'EOF'

Done. Open it from your app launcher, or run:   reiatsuflow

Hyprland (Lua config, e.g. ~/.config/hypr/custom/):
  hl.on("hyprland.start", function () hl.exec_cmd("reiatsuflow") end)
  hl.window_rule({match = {title = "^(ReiatsuFlow)$"}, workspace = "1 silent"})
  hl.window_rule({match = {title = "^(ReiatsuFlow Settings)$"}, float = true, size = {1060, 760}, center = true})

Hyprland (classic hyprland.conf):
  exec-once = reiatsuflow
  windowrule = workspace 1 silent, title:^(ReiatsuFlow)$
  windowrule = float, title:^(ReiatsuFlow Settings)$
EOF
