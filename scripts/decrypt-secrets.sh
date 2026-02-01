#!/usr/bin/env bash
# Decrypt all encrypted_*.age files to decrypted_* for editing
# Usage: ./scripts/decrypt-secrets.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGE_KEY_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/age-key.txt"
AGE_KEY="${AGE_KEY:-}"

# Get age key: env var > local file > 1Password
if [[ -n "$AGE_KEY" ]]; then
    echo "Using age key from AGE_KEY environment variable"
elif [[ -s "$AGE_KEY_FILE" ]]; then
    echo "Using age key from $AGE_KEY_FILE"
    AGE_KEY=$(cat "$AGE_KEY_FILE")
elif command -v op &>/dev/null && op account list &>/dev/null; then
    echo "Fetching age key from 1Password..."
    AGE_KEY=$(op read "op://Private/dotfiles-age-key/key")
else
    echo "Error: No age key found. Options:"
    echo "  1. Set AGE_KEY environment variable"
    echo "  2. Place key at $AGE_KEY_FILE"
    echo "  3. Sign in to 1Password CLI: op signin"
    exit 1
fi

# Find and decrypt all encrypted_*.age files
find "$REPO_ROOT" -name "encrypted_*.age" -type f | while read -r encrypted_file; do
    dir=$(dirname "$encrypted_file")
    filename=$(basename "$encrypted_file")

    # encrypted_foo.age -> decrypted_foo (stripped .age, encrypted_ -> decrypted_)
    plaintext_name="${filename%.age}"
    plaintext_name="${plaintext_name/encrypted_/decrypted_}"

    plaintext_file="$dir/$plaintext_name"

    echo "Decrypting: $encrypted_file"
    echo "        -> $plaintext_file"

    echo "$AGE_KEY" | age -d -i - "$encrypted_file" > "$plaintext_file"
done

echo "Done. Edit decrypted_* files, then run scripts/encrypt-secrets.sh"
