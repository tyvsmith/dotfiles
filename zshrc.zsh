#p10k instant promot
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

REPO=$(dirname $0)

source "$REPO/env.zsh"
source "$REPO/plugins.zsh"
source "$REPO/oh-my-zsh/oh-my-zsh.sh"
source "$REPO/functions.zsh"
source "$REPO/aliases.zsh"
source "$REPO/p10k.zsh"
