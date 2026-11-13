#!/bin/bash

command -v topgrade >/dev/null 2>&1 || exit 0

# Omarchy owns system and mise updates; gcloud is package-managed.
printf '\n── Topgrade — updating additional tools ──\n'
args=(--disable system mise gcloud)
if [[ ${OMARCHY_UPDATE_UNATTENDED:-0} == 1 ]]; then
    args+=(--yes --no-ask-retry)
fi
exec topgrade "${args[@]}"
