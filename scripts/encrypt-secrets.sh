#!/usr/bin/env bash
# Encrypt all decrypted_* files to encrypted_*.age
# Usage: ./scripts/encrypt-secrets.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_KEY_FILE="$REPO_ROOT/.age-public-key"

if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
    echo "Error: Public key not found at $PUBLIC_KEY_FILE"
    exit 1
fi

PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")

# Find and encrypt all decrypted_* files
find "$REPO_ROOT" -name "decrypted_*" -type f | while read -r plaintext_file; do
    dir=$(dirname "$plaintext_file")
    filename=$(basename "$plaintext_file")

    # decrypted_foo -> encrypted_foo.age
    encrypted_name="${filename/decrypted_/encrypted_}.age"
    encrypted_file="$dir/$encrypted_name"

    echo "Encrypting: $plaintext_file"
    echo "        -> $encrypted_file"

    age -r "$PUBLIC_KEY" -a "$plaintext_file" > "$encrypted_file"
done

echo "Done. Encrypted files are ready to commit."
