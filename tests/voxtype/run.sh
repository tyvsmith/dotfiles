#!/usr/bin/env bash
# voxtype-cleanup regression test harness.
# Tests the LLM cleanup script against the real model — no mocking.
# Run: ./tests/run.sh
# Skip conditions: missing secrets.env, missing env vars, no network hint.
#
# Tuning:
#   VOXTYPE_TEST_RUNS=3       — how many times to run each case (default 3)
#   VOXTYPE_TEST_THRESHOLD=2  — how many runs must pass for the case to pass (default 2)
set -uo pipefail

RUNS="${VOXTYPE_TEST_RUNS:-3}"
THRESHOLD="${VOXTYPE_TEST_THRESHOLD:-2}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/dot_local/bin/executable_voxtype-cleanup"
SECRETS="${VOXTYPE_SECRETS:-${XDG_CONFIG_HOME:-$HOME/.config}/voxtype/secrets.env}"
CONFIG="${VOXTYPE_CATEGORIES:-${XDG_CONFIG_HOME:-$HOME/.config}/voxtype/categories.yaml}"

# ── skip guards ──────────────────────────────────────────────────────────────

skip() { printf 'SKIP: %s\n' "$*"; exit 0; }

[[ -f "$SCRIPT" ]]   || skip "script not found at $SCRIPT"
[[ -f "$SECRETS" ]]  || skip "secrets.env not found at $SECRETS (set VOXTYPE_SECRETS to override)"
[[ -f "$CONFIG" ]]   || skip "categories.yaml not found at $CONFIG"

# Load the secrets file so tests have credentials available.
# Vars already present in the environment (even if empty) win over the file —
# use ${!_k+set} to detect "variable is set" regardless of value.
if [[ -r "$SECRETS" ]]; then
  while IFS='=' read -r _k _v; do
    [[ "$_k" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
    [[ "${!_k+set}" == "set" ]] && continue   # already in env (even if empty)
    _v="${_v%\"}"; _v="${_v#\"}"; _v="${_v%\'}"; _v="${_v#\'}"
    export "$_k=$_v"
  done < "$SECRETS"
fi

# Skip if any required var is still absent or empty after loading the file.
[[ -n "${VOXTYPE_LLM_API_KEY:-}" ]]  || skip "VOXTYPE_LLM_API_KEY not set (not in environment or secrets.env)"
[[ -n "${VOXTYPE_LLM_BASE_URL:-}" ]] || skip "VOXTYPE_LLM_BASE_URL not set (not in environment or secrets.env)"
[[ -n "${VOXTYPE_LLM_MODEL:-}" ]]    || skip "VOXTYPE_LLM_MODEL not set (not in environment or secrets.env)"

# To test the skip path: VOXTYPE_LLM_API_KEY="" ./tests/run.sh

# ── test case data ────────────────────────────────────────────────────────────
# Format: INPUT|HINT|MUST_MATCH (comma-sep regex)|MUST_NOT_MATCH (comma-sep regex)
# Regex uses bash =~ (ERE). Separate multiple patterns with §.

CASES=(
  # ── Regression #1: jargon over-substitution ─────────────────────────────
  # "open up lan mouse" must NOT be autocorrected to "hyprland".
  # The hyphenated form lan-mouse should appear; Hyprland must not be injected.
  "open up lan mouse|code|lan-mouse|[Hh]yprland"

  # ── Regression #2+3: refusal + pronoun flip ──────────────────────────────
  # A question about "my" setup: must not be refused and must not flip to "your".
  "what's in my chezmoi setup|code|my chezmoi§\?|your|I'm not able|I cannot|cannot process"

  # ── Regression #2b: pronoun flip in the reverse direction ───────────────
  # When the speaker dictates "your", it must stay "your" — the LLM must not
  # treat itself as the addressee and flip to "my".
  "i need your help debugging this|code|your help|my help"

  # ── Regression #4: filler removal + spelling correction ─────────────────
  # Filler words gone, hyperland → Hyprland, restart preserved.
  "um so like i need to restart hyperland you know|code|Hyprland§[Rr]estart|[Uu]m§\blike\b§you know§hyperland"

  # ── Question form preserved ──────────────────────────────────────────────
  "how do i restart hyprland|code|Hyprland§\?|hyperland"

  # ── Already-clean passthrough ────────────────────────────────────────────
  # No commentary or explanation added; core phrase intact.
  "git rebase onto main|code|git rebase onto main|Here is§This means§Let me§Note that"

  # ── Email: no fabricated salutation ─────────────────────────────────────
  "let me know if you have questions|email|[Ll]et me know§[Qq]uestions|Best,§Hi §Dear "

  # ── Chat: preserve casual markers ───────────────────────────────────────
  # lol must stay lol, not become LOL or be expanded.
  "lol that's wild|chat|lol|LOL§laughing out loud§Laughing"

  # ── Positive control A: basic filler removal ────────────────────────────
  # A clean, always-working case — if this fails the whole prompt is broken.
  "um uh so I need to fix this bug|code|fix.*bug|[Uu]m§[Uu]h§\bso\b I need"

  # ── Positive control B: capitalisation of known jargon ──────────────────
  "i've been using neovim and tmux|code|[Nn]eovim§[Tt]mux|neovim tmux"
)

# ── helpers ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
pass_count=0; fail_count=0; total=${#CASES[@]}

run_case() {
  local input="$1" hint="$2" must_raw="$3" must_not_raw="$4"
  local label="${input:0:50}"

  # Split § -delimited pattern lists into arrays
  IFS='§' read -ra must_pats     <<< "$must_raw"
  IFS='§' read -ra must_not_pats <<< "$must_not_raw"

  local run_passes=0
  local last_output=""

  for (( r=1; r<=RUNS; r++ )); do
    local out
    # Suppress voxtype-detect-category (not installed in dev env)
    out=$(printf '%s' "$input" \
      | VOXTYPE_SECRETS="$SECRETS" VOXTYPE_CATEGORIES="$CONFIG" \
        PATH="/usr/bin:/bin" \
        bash "$SCRIPT" --hint "$hint" 2>/dev/null)
    last_output="$out"

    local ok=1

    # must-match checks
    for pat in "${must_pats[@]}"; do
      [[ -z "$pat" ]] && continue
      if ! [[ "$out" =~ $pat ]]; then
        ok=0; break
      fi
    done

    # must-not-match checks
    if [[ $ok -eq 1 ]]; then
      for pat in "${must_not_pats[@]}"; do
        [[ -z "$pat" ]] && continue
        if [[ "$out" =~ $pat ]]; then
          ok=0; break
        fi
      done
    fi

    [[ $ok -eq 1 ]] && (( run_passes++ ))
  done

  if (( run_passes >= THRESHOLD )); then
    printf "${GREEN}PASS${RESET} [%d/%d] %s\n" "$run_passes" "$RUNS" "$label"
    (( pass_count++ ))
  else
    printf "${RED}FAIL${RESET} [%d/%d] %s\n" "$run_passes" "$RUNS" "$label"
    printf "       input:  %s\n" "$input"
    printf "       hint:   %s\n" "$hint"
    printf "       last output: %s\n" "$last_output"
    printf "       must match:     %s\n" "$must_raw"
    printf "       must not match: %s\n" "$must_not_raw"
    (( fail_count++ ))
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────

printf '\nvoxtype-cleanup regression suite\n'
printf 'Script:  %s\n' "$SCRIPT"
printf 'Model:   %s\n' "${VOXTYPE_LLM_MODEL}"
printf 'Runs/case: %d  Pass threshold: %d/%d\n\n' "$RUNS" "$THRESHOLD" "$RUNS"

for case_str in "${CASES[@]}"; do
  IFS='|' read -r tc_input tc_hint tc_must tc_must_not <<< "$case_str"
  run_case "$tc_input" "$tc_hint" "$tc_must" "$tc_must_not"
done

printf '\n─────────────────────────────────────────\n'
if (( fail_count == 0 )); then
  printf "${GREEN}ALL PASSED${RESET}  %d/%d cases\n" "$pass_count" "$total"
  exit 0
else
  printf "${RED}FAILURES${RESET}  %d passed, %d failed (of %d)\n" \
    "$pass_count" "$fail_count" "$total"
  exit 1
fi
