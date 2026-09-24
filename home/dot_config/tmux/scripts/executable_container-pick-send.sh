#!/usr/bin/env bash
# container-pick-send.sh — tmux popup wrapper for container-fzf
# Runs the multi-action container picker inside a tmux popup.
# The popup provides the TTY that fzf needs.

exec container-fzf --tmux
