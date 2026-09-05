#!/usr/bin/env bash

: <<'TMUX_GRIMOIRE'

   ╔═══════════════════════════════════════════════════════════════╗
   ║                                                               ║
   ║  ████████╗███╗   ███╗██╗   ██╗██╗   ██╗                       ║
   ║  ╚══██╔══╝████╗ ████║██║   ██║ ██╗ ██╔╝                       ║
   ║     ██║   ██╔████╔██║██║   ██║  ████╔╝                        ║
   ║     ██║   ██║╚██╔╝██║██║   ██║ ██╔═██╗                        ║
   ║     ██║   ██║ ╚═╝ ██║╚██████╔╝██╔╝  ██╗                       ║
   ║     ╚═╝   ╚═╝     ╚═╝ ╚═════╝ ╚═╝   ╚═╝                       ║
   ║                                                               ║
   ║   ██████╗ ██████╗ ██╗███╗   ███╗ ██████╗ ██╗██████╗ ███████╗  ║
   ║  ██╔════╝ ██╔══██╗██║████╗ ████║██╔═══██╗██║██╔══██╗██╔════╝  ║
   ║  ██║  ███╗██████╔╝██║██╔████╔██║██║   ██║██║██████╔╝█████╗    ║
   ║  ██║   ██║██╔══██╗██║██║╚██╔╝██║██║   ██║██║██╔══██╗██╔══╝    ║
   ║  ╚██████╔╝██║  ██║██║██║ ╚═╝ ██║╚██████╔╝██║██║  ██║███████╗  ║
   ║   ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝╚═╝  ╚═╝╚══════╝  ║
   ║                                                               ║ 
   ╚═══════════════════════════════════════════════════════════════╝

   Bash trick: Using : (no-op) with heredoc creates a comment block
   that bash parses but doesn't execute - perfect for ASCII art

TMUX_GRIMOIRE

# Resolve plugin directory for script paths
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# SINGLE-IPC OPTION FETCH: batch all tmux option reads into one display-message call
i=0
while IFS= read -r line; do
    opts[$i]="$line"
    ((i++))
done < <(tmux display-message -p '#{?@grimoire-key,#{@grimoire-key},}
#{?@ephemeral-grimoire-key,#{@ephemeral-grimoire-key},}
#{?@grimoire-kill-key,#{@grimoire-kill-key},}
#{?@grimoire-osc52,#{@grimoire-osc52},}')

# User-configurable keybindings
# set -g @grimoire-key ''
# set -g @ephemeral-grimoire-key ''
# set -g @grimoire-kill-key ''
grimoire_key=${opts[0]}
ephemeral_grimoire_key=${opts[1]}
grimoire_kill_key=${opts[2]}
grimoire_osc52=${opts[3]}

# Extend tmux PATH with plugin bin/ directory (parameter expansion avoids subprocess overhead)
env_line=$(tmux show-environment -g PATH 2>/dev/null || true)
current_path=${env_line#PATH=}
: "${current_path:=$PATH}"

# Calculate new PATH (idempotent: only append if not already present)
if [[ ":$current_path:" != *":$PLUGIN_DIR/bin:"* ]]; then
    new_path="$PLUGIN_DIR/bin:$current_path"
else
    new_path="$current_path"
fi

# Default keybindings (prefix + f/F/C/H) - overridden by user options
: "${grimoire_key:=f}"
: "${ephemeral_grimoire_key:=F}"
: "${grimoire_kill_key:=C}"
: "${grimoire_logo_key:=H}"

cast_shpell="$PLUGIN_DIR/scripts/cast_shpell.sh"
custom_shpell="$PLUGIN_DIR/bin/custom_shpell"
logo="$PLUGIN_DIR/bin/logo"
osc52="$PLUGIN_DIR/bin/osc52-copy"

tmux_cmd=(
    set-environment -g PATH "$new_path" \;
    bind-key "$grimoire_key" "run-shell '$cast_shpell standard'" \;
    bind-key "$ephemeral_grimoire_key" "run-shell '$cast_shpell ephemeral'" \;
    bind-key "$grimoire_kill_key" "run-shell '$cast_shpell kill'" \;
    bind-key "$grimoire_logo_key" "run-shell '$cast_shpell ephemeral grimoire \"$logo\"'" \;
    set -g @grimoire-custom-shpell "$custom_shpell" \;
    set -g @grimoire-osc52-copy "$osc52" \;
    set -g @shpell-grimoire-color "#c6b7ee" \;
    set -g @shpell-grimoire-width "45%" \;
    set -g @shpell-grimoire-height "55%" \;
    set -g @shpell-grimoire-position "top-center"
)

# OSC52 default copy bindings (opt-out via @grimoire-osc52 off)
# - y yanks vim-style: copy + clear selection, stay in copy mode.
#     We stash the selection in a tmux buffer then emit OSC52 from it via
#     run-shell so the pipe closes and osc52-copy's base64 gets EOF.
#     (copy-pipe alone leaves it hanging)
# - Enter cancels (exits copy mode).
if [[ "$grimoire_osc52" != "off" ]]; then
    emit_osc52="run-shell \"tmux save-buffer - | '$osc52'\""
    tmux_cmd+=( \;
        bind -T copy-mode-vi y "send-keys -X copy-selection ; $emit_osc52" \;
        bind -T copy-mode-vi Enter send-keys -X cancel
    )
fi

tmux "${tmux_cmd[@]}"
