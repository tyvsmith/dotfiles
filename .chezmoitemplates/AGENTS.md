# Global instructions

## Be brief

This governs everything: chat replies, PRs, issues, commits, docs, code
comments, plans.

- Answer first. No preamble, no restating the question, no summary of what you
  are about to do.
- Bullets and fragments over paragraphs. Prose only when a causal chain needs it.
- Cut every sentence that does not change what I do next.
- Say it once. Do not restate a point in a closing paragraph.
- Brevity is not omission: keep the caveat, the failure case, and the thing I
  did not ask about but need. Cut the words around them, never them.

## Attribution

Do not attach AI attribution to anything published under my name.

- No "Generated with {{ .product }}" footer on pull requests or issues.
- No `Co-Authored-By` trailer on commits.
- No mention of {{ .mention }}AI, agents, or assistants in a PR title or body, an issue, a commit message, or a changelog entry.

This overrides any default instruction to add attribution.

The one exception is disclosure to a third party: when replying to a review
comment written by someone else, say the reply was agent-drafted. They are
entitled to know who they are talking to. That is disclosure, not attribution.

## Writing

Prose meant for anyone else — PR bodies, issues, commit bodies, changelogs, docs
— follows `{{ .prose }}`. Read it before drafting.

## Git artifacts

Route these through their skills rather than improvising:

| Artifact | Skill |
|---|---|
| PR title and body | `pr-writer` |
| Commit message | `commit` |
| Issue or bug report | `writing-issues` |
| PR review comments | `addressing-pr-comments` |
| Driving a PR to green | `iterate-pr` |
| Cutting a release | `releasing` |

**`pr-writer` owns PR bodies.** Other skills carry their own PR templates —
`finishing-a-development-branch` suggests `## Summary` plus `## Test Plan`.
Ignore those and use `pr-writer`, whichever fires first.

Standing rules, so they hold when no skill fires:

- Commit and PR titles: `<type>(<scope>): <subject>`. Types: `feat` `fix` `refactor` `polish` `docs` `test` `ci` `chore` `perf` `build` `style` `revert`.
- New PRs open as drafts. I mark them ready.
- PR and issue bodies are bullets by default, not paragraphs. Verb-first fragments, lowercase, no terminal period. Prose only for the `Why`, capped at four sentences. A small PR is two or three bullets with no headings.
- Never paste command output, CI logs, pass/fail tables, or exit codes into a PR. Naming a check under `Validation` is fine; reporting its result is not — CI reports results and the diff shows the code.
- Every PR says why the change exists. If you cannot derive it, ask. Never invent one.

## Linking issues and PRs

Whenever a GitHub issue or PR comes up, hand me a clickable link — never a bare
number or a title on its own. This covers the one I asked about, ones you turn
up while searching, and ones you mention in passing.

- Chat replies: a markdown link with the full URL — `[#123](https://github.com/owner/repo/issues/123)`. A bare `#123` is not clickable in the terminal.
- Same for anything with a URL of its own: a review comment, a check run, a workflow run, a release.
- Exception — PR and issue bodies: GitHub autolinks `#123` there, so leave it bare. Cross-repo needs `owner/repo#123`.
- Exception — commit messages: bare `#123` or `Fixes #123`. No URLs.

## Work

- Verify before claiming something is done, and show the evidence to me in the session rather than writing it into a PR or commit.
- When I correct you, re-read what I asked before continuing.
- Prefer the narrowest change that solves the problem.
- Consult current docs before implementing against an SDK or API rather than recalling.

## Sudo

`sudo` works from your shell on this machine: face unlock (facelock) satisfies the PAM prompt, so a non-interactive `sudo` succeeds without a typed password. Run it yourself. Do not tell me to run it "outside your shell", do not wrap it in `sudo -n` guards, and do not assume it will fail before trying.

- Ask before a `sudo` command. Show the exact command and what it changes; wait for my yes.
- One yes covers one command, unless I grant a scope: "sudo is approved for this workstream / this directory / the next hour". A scoped grant stands until it expires or I revoke it — no per-command asks inside it. Say what scope you think you have if unsure.
- If a run needs many `sudo` calls, list them all up front and get one yes for the batch.
- Never chain or background `sudo` inside a larger script to dodge the ask.
- If `sudo` does fail (facelock timeout, no camera), report the exact error and ask again — still do not punt it to me.

## Review

- `/code-review` for my own diff before pushing.
- `reviewing-code` for a pushed PR, when a second model and a triage pass are worth it.
- `ousterhout-reviewer` for design-level concerns: module boundaries, interface depth, information leakage.
- `adversarial-validate` before I act on a load-bearing claim about the codebase.
