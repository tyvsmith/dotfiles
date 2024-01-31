
#wrappers for fast use of node and nvm to avoid slow session start
#still seems faster than the nvm zsh plugin
function _install_nvm() {
  unset -f nvm npm node
  # Set up "nvm" could use "--no-use" to defer setup, but we are here to use it
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

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
  local dir=`pwd`
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
  local args=("$@")
  local GW="$(upfind gradlew)"
  if [ -z "$GW" ]; then
    echo "Gradle wrapper not found."
  else
    $GW $args
  fi
}

function dw() {
  local args=("$@")
  local DW="$(upfind depw)"
  if [ -z "$DW" ]; then
    echo "dep wrapper not found."
  else
    $DW $args
  fi
}

function bw() {
  local args=("$@")
  local BW="$(upfind buckw)"
  if [ -z "$BW" ]; then
    echo "Buck wrapper not found."
  else
    $BW $args
  fi
}

#Provides a clean buck command execution
function bw-clean() { ( _bw-clean $@ ) }
function _bw-clean() {
  local args=("$@")
  local buckout="$(upfind buck-out)"
  export NO_BUCKD=${NO_BUCKD:-1}  
  if [ -z "$buckout" ]; then
    echo "buck-out not found."
  else
    echo "deleting contents of $buckout..."
    setopt localoptions rmstarsilent
    rm -rf "$buckout"/* 2> /dev/null
    args+=('--no-cache' '--config' 'cache.dir=""')
    bw $args
  fi
}

#Execute buck with a local buck binary set with LOCAL_BUCK_BINARY in your environment.
function bw-local() { ( _bw-local $@ ) }
function _bw-local() {
  local args=("$@")
  export NO_BUCKD=${NO_BUCKD:-1}
  export BUCK_BINARY=${BUCK_BINARY:-$LOCAL_BUCK_BINARY}
  if [ -z $BUCK_BINARY ]; then
      echo "BUCK_BINARY or LOCAL_BUCK_BINARY var not set"
  elif [ ! -f "$BUCK_BINARY" ]; then
      echo "Local Buck Binary not found. Location searched: $BUCK_BINARY"      
  elif [ ! -z $CLEAN_BUILD ]; then      
      _bw-clean $args
  else
      # args+=('--no-cache' '--config' 'cache.dir=""')
      bw $args
  fi
}


#Clean buck execution with local buck binary.
function bw-local-clean() { ( _bw-local-clean $@ ) }
function _bw-local-clean() {
  local args=("$@")
  local CLEAN_BUILD=1 
  _bw-local $args
}

function upcase() {
  echo $1 | tr [:lower:] [:upper:]
}

function downcase() {
  echo $1 | tr [:upper:] [:lower:]
}

function mklink() {
  if [ -d $2 ] ; then
    cmd.exe /c "mklink /J "${1//\//\\}" "${2//\//\\}
  else
    cmd.exe /c "mklink "${1//\//\\}" "${2//\//\\}
  fi
}

function hideHomeDotFilesForWindows() {
  IFS=$'\n'
  for item in $(/usr/bin/ls -A ~ | grep '^[.].*'); do

    echo "Hiding $(ls -dF "$item")"
    setHiddenInWindows "$item"

  done
}

setHiddenInWindows() {
	attrib.exe +h /l $1
}

chpwd() exa --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale

_ls_params+=(-I NTUSER.DAT\* -I ntuser.dat\*)