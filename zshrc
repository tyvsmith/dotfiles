#####################
# PATH              #
#####################
path=("$HOME/.dotfiles/bin" /usr/local/sbin /usr/local/bin "$path[@]")

#####################
# ENV VARIABLE      #
#####################
export EDITOR='vim'
export VISUAL=$EDITOR
export PAGER='less'
export SHELL=`which zsh`
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export BAT_THEME="Solarized (dark)"
export HOMEBREW_NO_ANALYTICS=1
export ENHANCD_FILTER=fzf:fzy:peco
export ERL_AFLAGS="-kernel shell_history enabled"
export OPERATING_SYSTEM=$(uname | tr '[:upper:]' '[:lower:]')
export TERM=xterm-256color
GREP_OPTIONS="--color=auto"

#####################
# ZINIT             #
#####################

#Load ziint base
source "$HOME/.dotfiles/zsh/zinit/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit


#####################
# THEME             #
#####################
POWERLEVEL10K_MODE='nerdfont-complete'
DEFAULT_USER=`whoami`

zinit light-mode for \
    depth=1 @romkatv/powerlevel10k \
    is-snippet ~/.dotfiles/zsh/p10k.zsh


#####################
# ZINIT ANNEXES     #
#####################
zinit light-mode for \
    @zinit-zsh/z-a-bin-gem-node \
    @zinit-zsh/z-a-rust \
    @zinit-zsh/z-a-readurl \
    @zinit-zsh/z-a-patch-dl

#####################
# ZINIT PLUGINS     #
#####################

#https://github.com/zdharma/fast-syntax-highlighting/issues/205 - Git disabled on zdharma/fast-syntax-highlighting


zinit light-mode wait lucid  for \
    @b4b4r07/enhancd \
    @ael-code/zsh-colored-man-pages \
    @hlissner/zsh-autopair \
    @le0me55i/zsh-extract \
    @jreese/zsh-titles \
    @xPMo/zsh-toggle-command-prefix \
    @wfxr/forgit \
    OMZ::lib/clipboard.zsh \
    OMZ::lib/directories.zsh \
    @zpm-zsh/ls \
    is-snippet ~/.dotfiles/zsh/ctrl-z-fzf.plugin.zsh \
    multisrc:'shell/*.zsh' @junegunn/fzf \
    atload='_set_fzf_history' @Aloxaf/fzf-tab \
    atload"!_zsh_autosuggest_start" zsh-users/zsh-autosuggestions \
    blockf zsh-users/zsh-completions atload"_history_substring_bind_keys" @zsh-users/zsh-history-substring-search \
    atinit" zpcompinit; zpcdreplay" atload"FAST_HIGHLIGHT[chroma-git]=0" zdharma/fast-syntax-highlighting


#####################
# ZINIT PROGRAMS    #
#####################

#Some of these are not available on servers, this creates availability

zinit wait silent light-mode as:program for \
    from:gh-r pick"bin/exa" @ogham/exa \
    from:gh-r mv:'bat-**/bat -> bat' @sharkdp/bat \
    from:gh-r mv"fd* -> fd" sbin"fd/fd"  @sharkdp/fd \
    pick"bin/git-dsf" zdharma/zsh-diff-so-fancy 
    
#    make @mbrubeck/compleat 
#    from:gh-r mv:"direnv* -> direnv" atclone'./direnv hook zsh > zhook.zsh' atpull'%atclone' pick"direnv" src="zhook.zsh" @direnv/direnv
#    from:gh-r  @junegunn/fzf-bin \




#####################
# COMPLETIONS       #
#####################

zinit wait lucid as'completion' light-mode blockf for \
    has'exa' https://github.com/ogham/exa/blob/master/completions/zsh/_exa \
    has'fd' https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/fd/_fd

local extract="
# trim input
local in=\${\${\"\$(<{f})\"%\$'\0'*}#*\$'\0'}
# get ctxt for current completion
local -A ctxt=(\"\${(@ps:\2:)CTXT}\")
# real path
local realpath=\${ctxt[IPREFIX]}\${ctxt[hpre]}\$in
realpath=\${(Qe)~realpath}
"

zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select=2
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*:descriptions' format '-- %d --'
zstyle ':completion:*:processes' command 'ps -au$USER'
zstyle ':completion:complete:*:options' sort false
zstyle ':fzf-tab:complete:_zlua:*' query-string input
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm,cmd -w -w"
zstyle ':fzf-tab:complete:kill:argument-rest' extra-opts --preview=$extract'ps --pid=$in[(w)1] -o cmd --no-headers -w -w' --preview-window=down:3:wrap
zstyle ':fzf-tab:complete:*:*' extra-opts --preview=$extract'$HOME/.dotfiles/bin/preview $realpath'

#####################
# SOURCES          #
#####################

zinit light-mode wait lucid is-snippet for \
    atinit='_source_local' /dev/null

#Workaround to source ones that include completions
_source_local() {
    autoload -Uz compinit && compinit
    source ~/.dotfiles/zsh/functions.zsh
    source ~/.dotfiles/zsh/aliases.zsh
    [ -f ~/.aliases.local ] && source ~/.aliases.local
    [ -f ~/.zshrc.local ] && source ~/.zshrc.local
}


#####################
# HISTORY           #
#####################
[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zhistory"
HISTSIZE=290000
SAVEHIST=$HISTSIZE

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
#ZSH_AUTOSUGGEST_MANUAL_REBIND=1
HISTORY_IGNORE='(l|ls|ll|cd|cd ..|pwd|exit|date|history)'

_set_fzf_history() {
    where fzf-history-widget | sed 's/fc -rl/fc -ril/' | source /dev/stdin \
		&& export FZF_CTRL_R_OPTS="--preview 'echo {1..3}; echo {4..} | bat --style=plain --language=zsh' --preview-window down:3:wrap --bind '?:toggle-preview'"
}

_history_substring_bind_keys() {
    if [ "$OPERATING_SYSTEM" = "darwin" ]; then
        bindkey '^[[A' history-substring-search-up
        bindkey '^[[B' history-substring-search-down
    elif [ "$OPERATING_SYSTEM" = "linux" ]; then
        # https://superuser.com/a/1296543
        # key dict is defined in /etc/zsh/zshrc
        bindkey "$key[Up]" history-substring-search-up
        bindkey "$key[Down]" history-substring-search-down
    fi

    bindkey -M vicmd 'k' history-substring-search-up
    bindkey -M vicmd 'j' history-substring-search-down
}

#####################
# SETOPT            #
#####################
setopt extendedglob           # Enable extended globbing
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_all_dups   # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt inc_append_history     # add commands to HISTFILE in order of execution
setopt share_history          # share command history data
setopt always_to_end          # cursor moved to the end in full completion
setopt hash_list_all          # hash everything before completion
setopt completealiases        # complete alisases
setopt always_to_end          # when completing from the middle of a word, move the cursor to the end of the word
setopt complete_in_word       # allow completion from within a word/phrase
setopt nocorrect              # spelling correction for commands
setopt list_ambiguous         # complete as much of a completion until it gets ambiguous.
# setopt vi                   #VI mode in terminal
setopt nolisttypes
setopt listpacked
setopt automenu

# awesome cd movements from zshkit
setopt autocd autopushd pushdminus pushdsilent pushdtohome cdablevars
DIRSTACKSIZE=5

#####################
# COLORING          #
#####################
autoload colors && colors

export CLICOLOR=1

#####################
# FZF SETTINGS      #
#####################

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS='--preview="$HOME/.dotfiles/bin/preview {}" --preview-window=right:60%:wrap'
export FZF_ALT_C_OPTS='--preview="HOME/.dotfiles/bin/preview {}" --preview-window=right:60%:wrap'
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--reverse
--height=50%
--pointer=➜ --prompt=➜ --marker=●
--color=fg:-1,bg:-1,hl:33,fg+:235,bg+:235,hl+:33
--color=info:136,prompt:136,pointer:230,marker:230,spinner:136'


#####################
# KEY BINDINGS      #
#####################
bindkey "^[[1;5D" emacs-backward-word
bindkey "^[[1;3D" emacs-backward-word
bindkey "^[[1;5C" emacs-forward-word
bindkey "^[[1;3C" emacs-forward-word

bindkey "^[[3;5~" kill-word
bindkey "^[[3;3~" kill-word