# Generado por trucha-theme desde ~/.config/trucha-os/templates/fish/conf.d/trucha-tema.fish: no editar a mano
# Colores de fish y fzf a juego con el tema de Trucha OS!

# resaltado de la línea de comandos
set -g fish_color_command '#ff5a5f'
set -g fish_color_keyword '#e5383b'
set -g fish_color_param '#cfcac5'
set -g fish_color_option '#8a8580'
set -g fish_color_quote '#e8b04b'
set -g fish_color_escape '#e8b04b'
set -g fish_color_redirection '#a32a2c'
set -g fish_color_operator '#e5383b'
set -g fish_color_end '#8a8580'
set -g fish_color_comment '#6a6a72'
set -g fish_color_autosuggestion '#4a4a52'
set -g fish_color_valid_path --underline
set -g fish_color_selection --background='#2a2a30'
set -g fish_color_search_match --background='#2a2a30'
set -g fish_color_cwd '#e5383b'
set -g fish_color_user '#ece8e4'
set -g fish_color_host '#8a8580'
# el error sigue siendo rojo en todos los temas (trucha-theme no recolorea esta línea)
set -g fish_color_error '#ff3b3b' --underline

# menú de autocompletado
set -g fish_pager_color_prefix '#e5383b' --bold
set -g fish_pager_color_completion '#ece8e4'
set -g fish_pager_color_description '#8a8580'
set -g fish_pager_color_progress '#e5383b'
set -g fish_pager_color_selected_background --background='#2a2a30'

# fzf
set -gx FZF_DEFAULT_OPTS "--color=bg+:#1a1a1e,bg:-1,spinner:#e5383b,hl:#e5383b,fg:#cfcac5,header:#e5383b,info:#e8b04b,pointer:#e5383b --color=marker:#ff5a5f,fg+:#f5f1ec,prompt:#e5383b,hl+:#ff5a5f,border:#4a4a52"
