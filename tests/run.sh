#!/usr/bin/env bash
# Run offline regression suites; installed desktop integrations skip if unavailable.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

for tool in python3 chezmoi age-keygen jq lua; do
    command -v "$tool" >/dev/null || { echo "Missing test dependency: $tool" >&2; exit 1; }
done

for suite in tests/*/; do
    if compgen -G "${suite}test_*.py" >/dev/null; then
        python3 -m unittest discover -s "$suite" -v
    fi
done

for test in tests/hypr/*.lua; do
    HYPR_WORKSPACE=6 lua "$test"
done
