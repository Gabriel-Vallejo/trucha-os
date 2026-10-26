# ─── Crimson Ink ──────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export BAT_THEME="ansi"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border=rounded --prompt='❯ ' --pointer='▌' --marker='●' \
  --color=bg+:#1a1a1e,bg:-1,spinner:#e5383b,hl:#e5383b,fg:#cfcac5,header:#e5383b,info:#e8b04b,pointer:#e5383b \
  --color=marker:#ff5a5f,fg+:#f5f1ec,prompt:#e5383b,hl+:#ff5a5f,border:#4a4a52"

if command -v eza >/dev/null; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -lah --icons=auto --group-directories-first --git'
  alias la='eza -a --icons=auto --group-directories-first'
  alias lt='eza --tree --level=2 --icons=auto'
fi
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
command -v fzf >/dev/null && eval "$(fzf --bash)"
command -v starship >/dev/null && eval "$(starship init bash)"

# fetch al abrir terminal: se lanza justo antes del primer prompt,
# cuando el terminal ya está listo (en el arranque kitty aún no responde)
__crimson_fetch() {
  # solo la primera vez; luego no hace nada (no se borra: hay terminales que reescriben PROMPT_COMMAND)
  [[ -n "$__CRIMSON_FETCHED" ]] && return
  __CRIMSON_FETCHED=1
  if [[ "$TERM" == "xterm-kitty" ]]; then
    # en kitty el torii es una imagen real recortada del fondo
    fastfetch --logo-type kitty-direct --logo ~/.config/fastfetch/logo.png --logo-width 26 --logo-height 13 --logo-padding-top 1
  else
    fastfetch
  fi
}
# (no en el terminal del panel de Claude: ahí molesta a los comandos automáticos)
if [[ $- == *i* && -z "$SSH_CONNECTION" && "$SHLVL" -le 2 && "$TERM_PROGRAM" != "claude-desktop" && -z "$TRUCHA_NOFETCH" ]] && command -v fastfetch >/dev/null; then
  PROMPT_COMMAND="__crimson_fetch;${PROMPT_COMMAND}"
fi
# ──────────────────────────────────────────────────────────────
