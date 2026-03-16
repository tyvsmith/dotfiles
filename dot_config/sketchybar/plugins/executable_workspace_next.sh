#!/usr/bin/env bash

CURRENT=$(aerospace list-workspaces --focused 2>/dev/null)
if [ "$CURRENT" -eq 9 ]; then
    NEXT=1
else
    NEXT=$((CURRENT + 1))
fi

aerospace workspace "$NEXT"
