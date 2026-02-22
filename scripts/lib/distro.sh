#!/usr/bin/env bash
# Distro detection functions for runtime use

detect_distro() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

is_macos() {
    [[ "$(detect_distro)" == "macos" ]]
}

is_arch() {
    [[ "$(detect_distro)" == "arch" ]]
}

is_debian() {
    [[ "$(detect_distro)" == "debian" ]]
}
