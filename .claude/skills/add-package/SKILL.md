---
name: add-package
description: >
  Add a new package to .chezmoidata/packages.yaml in the dotfiles repo at
  ~/Code/dotfiles. Verifies the canonical name on every supported manager
  (Homebrew formula + cask, Arch official + AUR, Ubuntu apt, Fedora dnf,
  Flathub, AppImage GitHub releases) via the bundled `pkg-lookup` helper (at `.claude/skills/add-package/pkg-lookup`) before writing
  the entry, so name overrides and cascade fields are correct by construction —
  never guessed. Use when the user says "add package <name>", "track <name> in
  chezmoi", "install <name> on all my machines", or is editing
  .chezmoidata/packages.yaml directly. Do not use for one-off `paru -S` or
  `brew install` invocations that are not meant to persist across machines.
---

# add-package

Add a new entry to `.chezmoidata/packages.yaml` with platform-correct names
verified against authoritative registries, not guessed.

## When to use

- User wants to add a package to the dotfiles so it installs on every machine
  on next `chezmoi apply`.
- User is editing `.chezmoidata/packages.yaml` directly and asks for help.
- The user mentions a tool by colloquial name (e.g., "fd", "Obsidian") and you
  need the actual install name on each manager.

## When NOT to use

- One-off installs the user does not want tracked.
- Updating an existing entry's version, description, or tags (no lookup needed
  — just edit).
- Removing an entry.
- Editing `.chezmoitemplates/cascade-filter` or any `run_onchange_*` install
  script.

## Workflow

Treat this as a strict sequence. Do not skip steps.

### 1. Confirm the package and intent

Ask the user (plain text is fine if only one short clarification is needed):

- Canonical/colloquial name (e.g., `bandwhich`, `Obsidian`, `LM Studio`).
- One-sentence description of what it does and why they want it.
- Any constraint: macOS-only? Linux-only? Specific desktop environment?

If you already have all this from the user's message, skip to step 2.

### 2. Look up the name on every manager

Run, in a single `Bash` tool call:

```sh
.claude/skills/add-package/pkg-lookup all <colloquial-name>
```

Read the aggregated JSON. For each manager, you get a `{found, name,
description, homepage, notes}` object. Show the user a short summary table
(brew / cask / pacman / aur / apt / dnf / flatpak — which were found and what
the canonical name was on each).

If the colloquial name is hyphenated/cased differently per manager, also try
likely variants — for example, `LM Studio` may live at `lmstudio` on brew,
`lmstudio-bin` on AUR, `ai.lmstudio.LMStudio` on Flathub. When in doubt,
search Flathub with the partial name (`.claude/skills/add-package/pkg-lookup flatpak <name>`) and
GitHub releases (`.claude/skills/add-package/pkg-lookup appimage <owner/repo>`) if the user mentions a
GitHub source.

### 3. Decide the YAML entry from the lookup results

Apply these rules in order:

1. **Same canonical name on every native manager** (brew == pacman == apt ==
   dnf): no overrides needed. Just write the YAML key.
2. **One manager uses a different name**: set just that manager's field to the
   string override. Leave the others absent.
   Example (from existing repo): `fd` has `apt: fd-find` and `dnf: fd-find`.
3. **Available on some managers, missing on others, and the cascade would
   pick the wrong one**: set the unavailable manager to `false` to skip it.
   Otherwise let the cascade fall through naturally.
4. **GUI app, macOS**: if `.claude/skills/add-package/pkg-lookup cask <name>` hits, set `brew_cask: true`.
   The cascade then makes pacman/apt/dnf the next stops on Linux.
5. **GUI app, no native Linux package**:
   - If Flathub has it: set `flatpak: <reverse-dns-app-id>` (from the
     `.claude/skills/add-package/pkg-lookup flatpak` result's `name` field).
   - If only an AppImage exists from a GitHub release: set
     `appimage: <owner>/<repo>` and verify with `.claude/skills/add-package/pkg-lookup appimage`.
6. **Requires a Homebrew tap**: set `brew_tap: "<tap>"` (e.g., `BarutSRB/tap`).
   See `omniwm` in the repo for the pattern.
7. **AUR-only Arch package**: set `pacman: <aur-name>` if the AUR name differs
   from the YAML key. Paru handles both repos.

After applying these rules, you should have a minimal entry — only fields that
differ from defaults. Read the schema comments at
`.chezmoidata/packages.yaml:9-39` if uncertain about defaults.

### 4. Confirm tags and description

Use `AskUserQuestion` with these options for `tags` (multi-select):

- `core` — installed on every profile (shell tools, base CLI)
- `container` — docker/podman/distrobox tooling
- `dev` — language SDKs, build tools, dev utilities
- `ai` — LLM CLIs and AI tooling
- `hardware` — bluetooth, monitor control, etc.
- `ui` — fonts, browser, editors, terminal, productivity GUI basics
- `ui-extra` — heavier GUI apps, optional desktop polish
- `gaming` — Steam and adjacent

Confirm the description string with the user verbatim — write what they said,
not your paraphrase.

### 5. Find the right section and insert

Section headers in `.chezmoidata/packages.yaml` are `# Title` lines bracketed
by `# ===` rules. Current sections (run `grep -n '^  # [A-Z]'
.chezmoidata/packages.yaml` to confirm):

- Shell & Environment, Editor, Modern CLI Replacements, Git Tools,
  Essential Utilities, Containers, Development SDKs & Package Managers,
  Build & Image Tools, Development Utilities, AI Tools,
  Basic UI — Fonts / Editor / Desktop Environment / Terminal / Productivity,
  Extended UI — Development / Terminals / Communication / Media & Utilities /
  macOS Apps, Gaming.

Pick the section that matches the tags + nature of the package. If unsure, ask
the user.

Insert alphabetically within the section using `Edit`. Match the indentation
of surrounding entries exactly (2-space indent for the key, 4-space for
fields).

### 6. Show the diff and ask before applying

Run `chezmoi diff` and summarize what changes — typically just the YAML edit,
plus possibly a new `run_onchange` hash that will retrigger one of the
install scripts on next apply.

Then ask the user via `AskUserQuestion` whether to run `chezmoi apply` now.
Default to **No** — let them apply on their schedule.

**Never** run `chezmoi apply` without an explicit yes.

## Schema cheatsheet

Authoritative source: `.chezmoidata/packages.yaml:9-39` (header comment).

- Cascade order: `brew → brew_cask → pacman → apt → dnf → rpm_ostree → flatpak → appimage`.
- Tri-state fields (`brew`, `pacman`, `apt`, `dnf`): **absent** = use YAML key,
  **string** = override, **false** = exclude from this manager.
- Modifiers: `brew_cask: true` flips to cask on macOS; `brew_tap: "<tap>"`
  preinstalls a tap.
- Opt-in: `rpm_ostree`, `flatpak`, `mas`, `appimage` are only used when the
  field is present AND truthy.
- Required fields: `tags`, `desc`.

## Examples

Simple, identical name everywhere:

```yaml
ripgrep:
  tags: [core]
  desc: "Fast recursive grep replacement"
```

Name override for two managers:

```yaml
fd:
  tags: [core]
  desc: "Simple, fast and user-friendly alternative to find"
  apt: fd-find
  dnf: fd-find
```

GUI app, brew_cask on macOS, Flathub on Linux:

```yaml
obsidian:
  tags: [ui]
  desc: "Markdown knowledge base"
  brew_cask: true
  flatpak: md.obsidian.Obsidian
```

Homebrew tap required:

```yaml
omniwm:
  tags: [ui]
  desc: "Window manager for macOS"
  os: darwin
  brew_cask: true
  brew_tap: "BarutSRB/tap"
```

AppImage as last-resort fallback:

```yaml
appflowy:
  tags: [ui-extra]
  desc: "Open-source Notion alternative"
  appimage: AppFlowy-IO/AppFlowy
```

## Edge cases

- **`fd` vs `fd-find`**: classic case where the apt and dnf packages live under
  `fd-find` but the binary is still `fd`. Always re-verify with
  `.claude/skills/add-package/pkg-lookup apt <name>` and `.claude/skills/add-package/pkg-lookup dnf <name>` — do not assume.
- **Bare AUR**: if `pacman` lookup misses but `aur` lookup hits, the YAML
  field is still `pacman: <name>` (paru installs both).
- **AUR `-bin` vs `-git`**: prefer the canonical, then `-bin`, then `-git`.
  Show the user which AUR variants exist and let them pick.
- **Flathub fuzzy search false-positives**: the helper filters search hits to
  ones whose app_id or name contains the query, but still verify the
  description matches the user's intent before committing to a `flatpak:`
  value.
- **AppImage rate-limits**: GitHub's unauthenticated API allows 60 requests/hr.
  If `.claude/skills/add-package/pkg-lookup appimage` returns a network error, try again later — do not
  guess the repo.
- **Cask without Linux equivalent**: if only `cask` exists and there's no
  Flatpak or AppImage, the package is macOS-only. Add `os: darwin` to make
  the constraint explicit.
- **Existing entry already present**: `grep -n '^  <name>:'
  .chezmoidata/packages.yaml` first. If the entry exists, ask the user
  whether they want to update it (different skill scope) or pick a different
  name.

## What not to do

- Do not invent a package name without evidence from the bundled helper. If a lookup
  misses, ask the user — do not guess.
- Do not edit `.chezmoitemplates/cascade-filter` or any
  `run_onchange_*-install-packages-*.sh.tmpl` script. The schema is fixed.
- Do not run `chezmoi apply` without explicit user approval.
- Do not modify existing entries as a side effect of adding a new one.
- Do not add fields that match the default (e.g., `enabled: true`,
  `brew_cask: false`). Keep entries minimal — only what differs from
  defaults.

## Tools used by this skill

- `Bash`: `.claude/skills/add-package/pkg-lookup all <name>` (and per-manager variants), `chezmoi diff`,
  `grep` against `.chezmoidata/packages.yaml`.
- `Read`: inspect `.chezmoidata/packages.yaml` to find the insertion point and
  confirm schema header.
- `Edit`: insert the new entry.
- `AskUserQuestion`: pick tags, confirm description, gate `chezmoi apply`.
