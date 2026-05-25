# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

plugins=(
git
dirhistory
history
#
fzf
#
zsh-autosuggestions
zsh-syntax-highlighting
zsh-autocomplete
)

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

###########################################

HISTSIZE=50000
#HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Aliases
alias ls='ls --color'
alias v='nvim'
alias c='clear'

###########################################

# ALL @END

export EDITOR="nvim"
export SUDO_EDITOR="$EDITOR"

[[ -f ~/.env.local ]] && source ~/.env.local

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[[ -f ~/.config/opencode/path.zsh ]] && source ~/.config/opencode/path.zsh
[[ -f ~/.config/opencode/secrets.env ]] && source ~/.config/opencode/secrets.env
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
export PATH="/opt/nvim-linux-x86_64/bin:$PATH"

# bun (24.04 only)
if [ -d "$HOME/.bun" ]; then
    [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi

bwget() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: bwget <item-name> [collection-id]" >&2
        return 1
    fi
    [[ -z "${BW_SESSION:-}" ]] && { echo "Error: BW_SESSION not set. Run: source vw-connect" >&2; return 1; }
    local name="$1"
    local coll="${2:-}"
    if [[ -n "$coll" ]]; then
        bw list items --collectionid "$coll" --session "$BW_SESSION" 2>/dev/null | jq --arg n "$name" -r '.[] | select(.name==$n) | .notes'
    else
        bw list items --session "$BW_SESSION" 2>/dev/null | jq --arg n "$name" -r '.[] | select(.name==$n) | .notes'
    fi
}

bwenv() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: bwenv <VAR_NAME>" >&2
        return 1
    fi
    [[ -z "${BW_SESSION:-}" ]] && { echo "Error: BW_SESSION not set. Run: source vw-connect" >&2; return 1; }
    local varname="$1"
    local value
    value=$(bw list items --session "$BW_SESSION" 2>/dev/null | jq --arg n "$varname" -r '.[] | select(.name==$n and .type==2) | .notes')
    if [[ -z "$value" ]]; then
        echo "Error: '$varname' not found in Vaultwarden" >&2
        return 1
    fi
    export "${varname}=${value}"
    echo "exported ${varname}"
}
