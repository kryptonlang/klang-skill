# Klang skill

> **Status: work in progress.** This is a skill we are preparing. It is not
> released. Instructions, APIs, and version notes may change.

Portable skill package for coding agents. The current skill teaches an agent
how to write, run, and debug Krypton (`.k` / `.ks`) programs without
rediscovering the language, CLI, and common failures every session.

Objective-K coverage tracks the source checkout. Published macOS 2.4.8 ships
the core `k:okui` facade and K-owned runtime; newer table, selection, keyboard,
and live-field APIs are still being prepared for 2.4.9. Re-check version notes
before treating a checkout-only API as released.

## Contents

```text
klang-skill/
├── install.sh              # global/project installer
├── README.md
└── krypton/
    ├── SKILL.md            # always-loaded overview
    ├── agents/
    │   └── openai.yaml     # Codex metadata
    └── references/
        ├── language.md
        ├── cli.md
        ├── stdlib.md
        ├── objective-k.md
        ├── troubleshooting.md
        └── caveman-fallback.md
```

`SKILL.md` is intentionally short. Detailed material lives in `references/`
and is loaded only when needed. `references/objective-k.md` is the deep dive
for native macOS apps, AppKit tables and events, the K-owned runtime, and the
Windows backend differences.

## Install

```bash
# Global: OpenCode, Claude Code, Codex, Freebuff
./install.sh

# Project-local
./install.sh --project .

# Copy instead of symlink
./install.sh --copy

# Include caveman for every agent (auto-detect local caveman source)
./install.sh --with-caveman

# Remove
./install.sh --uninstall
```

The installer symlinks by default, so editing this directory updates every
agent. Use `--copy` for a self-contained install.

## Agent discovery paths

| Agent | Global | Project |
|---|---|---|
| OpenCode | `~/.config/opencode/skills/krypton` | `.opencode/skills/krypton` |
| Claude Code | `~/.claude/skills/krypton` | `.claude/skills/krypton` |
| Codex | `~/.codex/skills/krypton` | `.codex/skills/krypton` |
| Freebuff / Codebuff | `~/.agents/skills/krypton` | `.agents/skills/krypton` |

OpenCode and Freebuff also read the compatibility paths, so a single
`~/.agents/skills/krypton` can serve both when configured that way.

## Caveman pairing

The Krypton skill is designed to run with the `caveman` skill. `SKILL.md`
instructs the agent to load `caveman` first and provides a fallback style
guide if it is unavailable.

Auto mode installs caveman only for OpenCode and Freebuff. Claude Code and
Codex normally already have caveman as a plugin. Use `--with-caveman` to add
a skill copy everywhere.

## Invoke

```text
use the krypton skill
@krypton
/skill:krypton
$krypton
```

Exact syntax depends on the agent. Restart or reload after installing.

## Maintenance

- Keep `SKILL.md` under a few hundred lines.
- Add new failure modes to `references/troubleshooting.md`.
- Add new stdlib modules to `references/stdlib.md` only after testing them.
- Re-test closure, time, random, URL, datetime, and Objective-K notes on each
  release, especially 2.4.9.
