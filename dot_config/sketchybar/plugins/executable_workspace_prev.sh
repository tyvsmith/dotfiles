#!/usr/bin/env bash

CURRENT=$(aerospace list-workspaces --focused 2>/dev/null)
if [ "$CURRENT" -eq 1 ]; then
    PREV=9
else
    PREV=$((CURRENT - 1))
fi

aerospace workspace "$PREV"
