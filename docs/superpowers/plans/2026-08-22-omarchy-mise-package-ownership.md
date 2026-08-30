# Omarchy and mise Package Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate Chezmoi's declarative runtime configuration from Omarchy's mutable lazy-wrapper state, and route Arch repository and AUR packages through the appropriate interface without removing existing software.

**Architecture:** Chezmoi will manage `~/.config/mise/conf.d/10-dotfiles.toml`; Omarchy will retain ownership of `~/.config/mise/config.toml` and `~/.local/bin` wrappers. The Arch installer will classify packages dynamically with `pacman -Si`, then use Omarchy's package commands on Omarchy and native pacman/paru on generic Arch.

**Tech Stack:** Chezmoi Go templates, Bash, mise TOML, pacman, yay/paru, Omarchy CLI, Fish, ShellCheck.

---

## Implementation constraints

- Work in a dedicated worktree created from the branch the user selects at execution time. Do not switch branches in the user's primary checkout.
- Do not modify `/usr/share/omarchy`, `/usr/bin/omarchy-*`, or `~/.local/bin` wrappers.
- Do not run package removal or mise cleanup commands.
- Do not edit `.chezmoidata/packages.yaml` in this implementation. Its desired agent exclusions already exist, and the working tree currently contains unrelated user changes:

  - Add `tealdeer`.
  - Remove `visual-studio-code-insiders`.

- Do not stage or commit `.chezmoidata/packages.yaml`.
- Do not run an unrestricted, non-dry-run `chezmoi apply`.
- The package-routing script may install packages when executed normally. Tests must inspect rendered text; never execute it against real package managers during automated verification.

## File map

- Create: `dot_config/mise/conf.d/10-dotfiles.toml.tmpl` — declarative runtime defaults and settings.
- Delete: `dot_config/mise/config.toml.tmpl` — releases mutable `config.toml` to Omarchy.
- Modify: `run_onchange_12-install-packages-pacman.sh.tmpl` — repository/AUR classification and host-specific routing.
- Create: `scripts/audit-tool-ownership.sh` — read-only resolution and ownership report.
- Create: `tests/package-management/run.sh` — regression checks for the ownership boundary and rendered installer.
- Modify: `CLAUDE.md` — authoritative repository architecture and package policy.
- Modify: `README.md` — concise user-facing ownership guidance.
- Do not modify: `.chezmoidata/packages.yaml`, Omarchy files, live wrappers, or installed-package state.

### Task 1: Add a failing ownership-policy regression test

**Files:**

- Create: `tests/package-management/run.sh`
- Test: `tests/package-management/run.sh`

- [ ] **Step 1: Confirm the working baseline and protected user diff**

Run:

```bash
cd /home/ty/Code/dotfiles
git status --short --branch
git diff -- .chezmoidata/packages.yaml
```

Expected: `.chezmoidata/packages.yaml` is modified with the `tealdeer` addition and VS Code Insiders removal. Record the current branch name and create the implementation worktree from the branch the user chooses. If the package diff has changed, stop and reconcile with the user rather than overwriting it.

- [ ] **Step 2: Create the regression test**

Create `tests/package-management/run.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root"

failures=0

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_file() {
  if [[ -f $1 ]]; then pass "$2"; else fail "$2"; fi
}

assert_absent() {
  if [[ ! -e $1 ]]; then pass "$2"; else fail "$2"; fi
}

assert_contains() {
  local text=$1 pattern=$2 label=$3
  if grep -Fq -- "$pattern" <<<"$text"; then pass "$label"; else fail "$label"; fi
}

assert_file dot_config/mise/conf.d/10-dotfiles.toml.tmpl \
  'Chezmoi owns a mise conf.d drop-in'
assert_absent dot_config/mise/config.toml.tmpl \
  'Chezmoi does not own mutable mise config.toml'

rendered=$(chezmoi --source "$repo_root" execute-template < run_onchange_12-install-packages-pacman.sh.tmpl)
bash -n <<<"$rendered"
assert_contains "$rendered" 'REPO_PACKAGES=()' \
  'Rendered installer separates repository packages'
assert_contains "$rendered" 'AUR_PACKAGES=()' \
  'Rendered installer separates AUR packages'
assert_contains "$rendered" 'omarchy pkg add' \
  'Omarchy repository packages use omarchy pkg add'
assert_contains "$rendered" 'omarchy pkg aur add' \
  'Omarchy AUR packages use omarchy pkg aur add'

for package in opencode claude-code codex gemini-cli; do
  if grep -Eq "^  ${package}:" .chezmoidata/packages.yaml; then
    fail "$package is active in packages.yaml"
  else
    pass "$package is not active in packages.yaml"
  fi
done

gh_block=$(sed -n '/^  gh:/,/^  [a-zA-Z0-9_-]\+:/p' .chezmoidata/packages.yaml | head -n -1)
assert_contains "$gh_block" 'pacman: false' \
  'gh remains excluded from pacman'

if (( failures > 0 )); then
  printf '%d package-management test(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'All package-management tests passed\n'
```

Set its executable bit:

```bash
chmod +x tests/package-management/run.sh
```

- [ ] **Step 3: Run the test and verify it fails for the intended reasons**

Run:

```bash
tests/package-management/run.sh
```

Expected: failures report that the new `conf.d` template is absent, the old `config.toml` template still exists, and the rendered installer lacks separate repository/AUR routes. The existing package-exclusion checks should pass.

Do not commit the failing test separately.

### Task 2: Split declarative and Omarchy-owned mise configuration

**Files:**

- Create: `dot_config/mise/conf.d/10-dotfiles.toml.tmpl`
- Delete: `dot_config/mise/config.toml.tmpl`
- Test: `tests/package-management/run.sh`

- [ ] **Step 1: Add the Chezmoi-owned drop-in**

Create `dot_config/mise/conf.d/10-dotfiles.toml.tmpl` with:

```toml
{{ if contains "dev" .tags -}}
# Global runtime policy owned by Chezmoi. Omarchy owns the mutable
# ~/.config/mise/config.toml used by its lazy wrappers.
#
# Python intentionally remains a system global. A mise-managed global Python
# can break Arch applications whose /usr/bin/env python3 entrypoints require
# pacman-provided modules such as PyGObject. Select Python per project instead.
[tools]
bun = "latest"
node = "latest"
rust = "latest"
go = "latest"
java = "latest"
{{ if ne .de "hyprland-omarchy" -}}
# Non-Omarchy development profiles do not receive Omarchy's lazy wrappers.
claude = "latest"
codex = "latest"
{{ end -}}

[settings]
idiomatic_version_file_enable_tools = ["node", "python", "go", "ruby", "java", "rust"]
# Arch's /usr/bin/go must derive its own GOROOT while building AUR packages.
go_set_goroot = false
# Keep mise's npm-backed tools isolated with its embedded package manager.
npm.package_manager = "aube"
{{ end -}}
```

- [ ] **Step 2: Remove the source template for mutable config.toml**

Delete `dot_config/mise/config.toml.tmpl` from the source tree. Do not delete or edit the live `~/.config/mise/config.toml`.

- [ ] **Step 3: Render and parse the new configuration without installing tools**

Run:

```bash
mkdir -p /tmp/dotfiles-mise-plan
chezmoi --source "$PWD" execute-template < dot_config/mise/conf.d/10-dotfiles.toml.tmpl > /tmp/dotfiles-mise-plan/10-dotfiles.toml
MISE_GLOBAL_CONFIG_FILE=/tmp/dotfiles-mise-plan/10-dotfiles.toml mise config ls
```

Expected: mise lists `/tmp/dotfiles-mise-plan/10-dotfiles.toml` without a TOML parse error. The rendered Omarchy profile contains Bun, Node, Rust, Go, and Java but not Claude or Codex.

- [ ] **Step 4: Verify Chezmoi's target map without applying it**

Run:

```bash
chezmoi --source "$PWD" managed --include=files | rg '^\.config/mise/'
chezmoi --source "$PWD" diff
```

Expected: only `.config/mise/conf.d/10-dotfiles.toml` is managed. The diff proposes creation of the drop-in and does not propose deleting the live `config.toml`.

If Chezmoi proposes deleting `~/.config/mise/config.toml`, stop. Preserve it with:

```bash
cp ~/.config/mise/config.toml /tmp/dotfiles-mise-plan/config.toml.preserved
```

Then investigate the source-state transition before applying anything.

- [ ] **Step 5: Commit the mise ownership split**

Run:

```bash
git add dot_config/mise/conf.d/10-dotfiles.toml.tmpl dot_config/mise/config.toml.tmpl tests/package-management/run.sh
git commit -m "refactor(mise): separate dotfiles defaults from omarchy state"
```

Expected: the commit contains the template move and regression test only. `.chezmoidata/packages.yaml` remains unstaged.

### Task 3: Route configured-repository and AUR packages separately

**Files:**

- Modify: `run_onchange_12-install-packages-pacman.sh.tmpl`
- Test: `tests/package-management/run.sh`

- [ ] **Step 1: Replace the single paru route with dynamic classification**

Keep the existing header, profile guard, hashes, and generated `CANDIDATE_PACKAGES` declarations. Replace the body from `set -euo pipefail` through the final completion message with the following structure, retaining the generated candidate loop exactly where marked:

```bash
set -euo pipefail

# shellcheck source=/dev/null
source "${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/scripts/lib/common.sh"

{{ $isOmarchy := eq .de "hyprland-omarchy" -}}
{{ if $isOmarchy -}}
log "Using profile '{{ .profile }}' — routing packages through Omarchy"
require_cmd omarchy
require_cmd yay
AUR_HELPER=yay
{{ else -}}
log "Using profile '{{ .profile }}' — routing packages through pacman/paru"
ensure_pkg paru paru-bin
AUR_HELPER=paru
{{ end }}

declare -A CANDIDATE_PACKAGES=()  # pkg_name -> display_name
{{- range $key, $pkg := .packages }}
{{-   template "cascade-filter" (dict "root" $ "pkg" $pkg "key" $key "manager" "pacman" "fmt" "CANDIDATE_PACKAGES[%s]=\"%s\"") }}
{{- end }}

REPO_PACKAGES=()
AUR_PACKAGES=()
MISSING_PACKAGES=()

for pkg_name in "${!CANDIDATE_PACKAGES[@]}"; do
  if pacman -Si -- "$pkg_name" &>/dev/null; then
    REPO_PACKAGES+=("$pkg_name")
  elif "$AUR_HELPER" -Si -- "$pkg_name" &>/dev/null; then
    AUR_PACKAGES+=("$pkg_name")
  else
    MISSING_PACKAGES+=("${CANDIDATE_PACKAGES[$pkg_name]}")
  fi
done

mapfile -t REPO_PACKAGES < <(printf '%s\n' "${REPO_PACKAGES[@]}" | sed '/^$/d' | sort)
mapfile -t AUR_PACKAGES < <(printf '%s\n' "${AUR_PACKAGES[@]}" | sed '/^$/d' | sort)
mapfile -t MISSING_PACKAGES < <(printf '%s\n' "${MISSING_PACKAGES[@]}" | sed '/^$/d' | sort)

log "Installing ${#REPO_PACKAGES[@]} packages from configured repositories..."
if (( ${#REPO_PACKAGES[@]} > 0 )); then
{{ if $isOmarchy -}}
  omarchy pkg add "${REPO_PACKAGES[@]}"
{{ else -}}
  sudo pacman -S --needed --noconfirm "${REPO_PACKAGES[@]}"
{{ end -}}
fi

log "Installing ${#AUR_PACKAGES[@]} packages from the AUR..."
if (( ${#AUR_PACKAGES[@]} > 0 )); then
{{ if $isOmarchy -}}
  omarchy pkg aur add "${AUR_PACKAGES[@]}"
{{ else -}}
  paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"
{{ end -}}
fi

if (( ${#MISSING_PACKAGES[@]} > 0 )); then
  warn "The following packages are not available in configured repositories or the AUR:"
  for pkg in "${MISSING_PACKAGES[@]}"; do
    warn "  - $pkg"
  done
fi

log ""
log "Arch package installation complete!"
```

Important: this is runtime classification. Do not hard-code the six packages currently reported as AUR because CachyOS, Omarchy, and plain Arch expose different configured repositories.

- [ ] **Step 2: Render and syntax-check the Omarchy branch**

Run:

```bash
chezmoi --source "$PWD" execute-template < run_onchange_12-install-packages-pacman.sh.tmpl > /tmp/dotfiles-mise-plan/install-packages-arch.sh
bash -n /tmp/dotfiles-mise-plan/install-packages-arch.sh
shellcheck /tmp/dotfiles-mise-plan/install-packages-arch.sh
```

Expected: both commands exit zero. The rendered script contains `AUR_HELPER=yay`, `omarchy pkg add`, and `omarchy pkg aur add`; it does not execute during this check.

- [ ] **Step 3: Run the regression test**

Run:

```bash
tests/package-management/run.sh
```

Expected: all tests pass.

- [ ] **Step 4: Commit the package routing change**

Run:

```bash
git add run_onchange_12-install-packages-pacman.sh.tmpl
git commit -m "refactor(packages): separate repository and AUR routes"
```

Expected: `.chezmoidata/packages.yaml` remains unstaged.

### Task 4: Add a read-only tool-ownership audit

**Files:**

- Create: `scripts/audit-tool-ownership.sh`

- [ ] **Step 1: Create the audit script**

Create `scripts/audit-tool-ownership.sh` with:

```bash
#!/usr/bin/env bash
set -uo pipefail

commands=(
  gh claude codex opencode gemini copilot crush
  playwright pi omp grok ghui hunk
  bun bunx node npm npx uv mise
)

printf 'command\tresolved-path\tpacman-owner\tmise-path\tomarchy-wrapper\n'

for command_name in "${commands[@]}"; do
  resolved=$(command -v -- "$command_name" 2>/dev/null || true)
  pacman_owner=-
  mise_path=-
  wrapper=-

  if [[ -n $resolved ]]; then
    pacman_owner=$(pacman -Qoq -- "$resolved" 2>/dev/null || printf '%s' -)
  else
    resolved=-
  fi

  if command -v mise >/dev/null 2>&1; then
    mise_path=$(mise which "$command_name" 2>/dev/null || printf '%s' -)
  fi

  wrapper_path="$HOME/.local/bin/$command_name"
  if [[ -x $wrapper_path ]]; then
    wrapper=$(sed -n 's/^mise use -g "\(.*\)".*/\1/p' "$wrapper_path")
    [[ -n $wrapper ]] || wrapper=present
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$command_name" "$resolved" "$pacman_owner" "$mise_path" "$wrapper"
done
```

Set its executable bit:

```bash
chmod +x scripts/audit-tool-ownership.sh
```

- [ ] **Step 2: Verify it is read-only and syntactically valid**

Run:

```bash
bash -n scripts/audit-tool-ownership.sh
shellcheck scripts/audit-tool-ownership.sh
scripts/audit-tool-ownership.sh
```

Expected: a tab-separated report. It should reveal both pacman and mise ownership where duplicates exist, but it must not change `git status`, `mise ls --current`, or the pacman database.

- [ ] **Step 3: Commit the audit utility**

Run:

```bash
git add scripts/audit-tool-ownership.sh
git commit -m "feat(packages): add tool ownership audit"
```

### Task 5: Document the ownership policy

**Files:**

- Modify: `CLAUDE.md`
- Modify: `README.md`

- [ ] **Step 1: Update `CLAUDE.md` package-management architecture**

Replace the Arch bullet that says all packages are installed via paru with:

```markdown
- **Omarchy:** configured-repository packages through `omarchy pkg add`; AUR-only packages through `omarchy pkg aur add`
- **Generic Arch:** configured-repository packages through pacman; AUR-only packages through paru
```

Add this subsection after the package-manager cascade description:

```markdown
### Tool Ownership

- Native packages own operating-system components, services, shared libraries, desktop applications, and standalone tools such as `uv`.
- Mise owns versioned language runtimes. Python is deliberately not global; select it per project.
- On Omarchy, its lazy wrappers own agent/TUI selections in `~/.config/mise/config.toml` and the wrapper files in `~/.local/bin`.
- Chezmoi owns runtime defaults and mise settings in `~/.config/mise/conf.d/10-dotfiles.toml`.
- Project dependencies remain with their project-native manager (`uv`, Bun/npm, Cargo, or Go modules).

Do not edit or track Omarchy's wrapper files. Do not add an Omarchy-wrapped agent to `packages.yaml`; launch its wrapper and let Omarchy/mise install it.
```

Update the key-files and install-script tables to name the new drop-in and the split repo/AUR behavior.

- [ ] **Step 2: Add concise user guidance to `README.md`**

Add this section after the profile/package overview:

```markdown
## Package and Tool Ownership

- Use native packages for OS-integrated software and desktop applications.
- Use mise for language runtimes and Omarchy's lazy agent wrappers.
- Use project managers for project dependencies.
- On Omarchy, the dotfiles leave `~/.config/mise/config.toml` and `~/.local/bin` wrappers to Omarchy. Declarative runtime defaults live in `~/.config/mise/conf.d/10-dotfiles.toml`.

Run `scripts/audit-tool-ownership.sh` to see which executable currently wins and whether pacman, mise, or an Omarchy wrapper provides it.
```

- [ ] **Step 3: Verify documentation matches implementation**

Run:

```bash
rg -n 'paru handles both|config\.toml\.tmpl|conf\.d/10-dotfiles|omarchy pkg aur add|Tool Ownership' CLAUDE.md README.md
```

Expected: no remaining claim that every Arch package goes through paru; both documents describe the split ownership model.

- [ ] **Step 4: Commit documentation**

Run:

```bash
git add CLAUDE.md README.md
git commit -m "docs: explain omarchy and mise ownership"
```

### Task 6: Verify the live migration without removing or upgrading anything

**Files:**

- Live create after approval: `~/.config/mise/conf.d/10-dotfiles.toml`
- Live preserve: `~/.config/mise/config.toml`

- [ ] **Step 1: Capture the pre-apply state**

Run:

```bash
cp ~/.config/mise/config.toml /tmp/dotfiles-mise-plan/config.toml.before
mise config ls
mise ls --current
scripts/audit-tool-ownership.sh
```

Expected: the existing live config lists the wrapper-selected tools. This is the recovery copy; do not place it in the repository.

- [ ] **Step 2: Preview only the new drop-in**

Run:

```bash
chezmoi --source "$PWD" diff -- ~/.config/mise/conf.d/10-dotfiles.toml
chezmoi --source "$PWD" apply --dry-run --verbose ~/.config/mise/conf.d/10-dotfiles.toml
```

Expected: creation of one drop-in. No package-install script and no deletion or rewrite of `~/.config/mise/config.toml`.

- [ ] **Step 3: Apply only the drop-in after reviewing the preview**

Run:

```bash
chezmoi --source "$PWD" apply --verbose ~/.config/mise/conf.d/10-dotfiles.toml
```

Expected: exactly one target file is created. This command is appropriate only after the executing agent has shown the dry-run result to the user and received approval for the live config write.

- [ ] **Step 4: Confirm both config layers and existing tools survive**

Run:

```bash
cmp /tmp/dotfiles-mise-plan/config.toml.before ~/.config/mise/config.toml
mise config ls
mise ls --current
fish -lc 'type -a gh claude codex opencode gemini ghui grok pi omp'
scripts/audit-tool-ownership.sh
```

Expected:

- `cmp` exits zero: the mutable Omarchy config was untouched.
- `mise config ls` lists both `config.toml` and `conf.d/10-dotfiles.toml`.
- Existing selected tools remain current.
- No command-resolution regression is introduced.

- [ ] **Step 5: Record, but do not act on, cleanup candidates**

Run:

```bash
pacman -Qi github-cli gemini-cli nodejs npm uv mise paru yay | rg '^(Name|Version|Install Reason|Required By)'
mise ls --current
```

Expected cleanup candidates for a separate decision:

- `github-cli`: native/mise duplicate.
- `gemini-cli`: native package while an Omarchy wrapper also exists.
- `paru`: redundant if the user standardizes on Omarchy's yay-backed AUR command.
- Old mise runtime versions: review project references before any prune.

Do not remove any of them in this plan.

### Task 7: Final verification and handoff

**Files:**

- Verify all changed files.

- [ ] **Step 1: Run all static and regression checks**

Run:

```bash
tests/package-management/run.sh
shellcheck scripts/audit-tool-ownership.sh
chezmoi --source "$PWD" execute-template < run_onchange_12-install-packages-pacman.sh.tmpl > /tmp/dotfiles-mise-plan/install-packages-arch.sh
bash -n /tmp/dotfiles-mise-plan/install-packages-arch.sh
shellcheck /tmp/dotfiles-mise-plan/install-packages-arch.sh
git diff --check
```

Expected: every command exits zero.

- [ ] **Step 2: Confirm protected files and external state**

Run:

```bash
git status --short
git diff -- .chezmoidata/packages.yaml
pacman -Q github-cli gemini-cli paru yay
```

Expected:

- The original package YAML user diff is unchanged and unstaged.
- All four packages remain installed.
- No Omarchy wrapper file appears in `git status` or Chezmoi's managed-file list.

- [ ] **Step 3: Review commits and final diff**

Run:

```bash
git log --oneline --decorate -6
git diff HEAD~4..HEAD --stat
git diff HEAD~4..HEAD -- . ':(exclude).chezmoidata/packages.yaml'
```

Expected: focused commits for the mise split, package routing, audit utility, and documentation. There must be no package removal, wrapper edit, or change under `/usr/share/omarchy`.

- [ ] **Step 4: Report the deferred decisions**

The handoff must explicitly say:

- Omarchy wrappers remain authoritative for agent selections.
- Chezmoi now owns only the mise drop-in.
- Existing package/mise duplicates were intentionally retained.
- A future cleanup can decide whether to remove `github-cli`, `gemini-cli`, `paru`, and unused mise versions after observing the new setup.
