
#wrappers for fast use of node and nvm to avoid slow session start
#still seems faster than the nvm zsh plugin
function _install_nvm() {
  unset -f nvm npm node
  # Set up "nvm" could use "--no-use" to defer setup, but we are here to use it
  [ -s "$HOME/.nvm/nvm.sh" ] && . $HOME/.nvm/nvm.sh # This sets up nvm
  [ -s "$HOME/.nvm/bash_completion" ] && \. "$HOME/.nvm/bash_completion"  # nvm bash_completion
  "$@"
}

function nvm() {
    _install_nvm nvm "$@"
}

function npm() {
    _install_nvm npm "$@"
}

function node() {
    _install_nvm node "$@"
}


#Buck/Gradle
function upfind() {
  dir=`pwd`
  while [ "$dir" != "/" ]; do
    p=`find "$dir" -maxdepth 1 -name $1`
    if [ ! -z $p ]; then
      echo "$p"
      return
    fi
    dir=`dirname "$dir"`
  done
}

function gw() {
  GW="$(upfind gradlew)"
  if [ -z "$GW" ]; then
    echo "Gradle wrapper not found."
  else
    $GW $@
  fi
}

function dw() {
  DW="$(upfind depw)"
  if [ -z "$DW" ]; then
    echo "dep wrapper not found."
  else
    $DW $@
  fi
}

function bw() {
  BW="$(upfind buckw)"
  if [ -z "$BW" ]; then
    echo "Buck wrapper not found."
  else
    $BW $@
  fi
}

function upcase() {
  echo $1 | tr [:lower:] [:upper:]
}

function downcase() {
  echo $1 | tr [:upper:] [:lower:]
}

chpwd() exa --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale
