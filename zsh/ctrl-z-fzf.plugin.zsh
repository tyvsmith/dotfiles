# Uses Ctrl+Z to foreground and background processes.

function _fg-fzf() {
	job="$(jobs | fzf -0 -1 | sed -E 's/\[(.+)\].*/\1/')" && echo '' && fg %$job
}
function _ctrl-z-fzf () {
	if [[ $#BUFFER -eq 0 ]]; then
		BUFFER="_fg-fzf"
		zle accept-line -w
	else
		zle push-input -w
		zle clear-screen -w
	fi
}

zle -N _ctrl-z-fzf
bindkey '^Z' _ctrl-z-fzf