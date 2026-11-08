# Klang skill

Agent guidance for **released macOS arm64 Krypton 2.4.9**, with separate
Linux/Windows version boundaries. This package does not install the compiler.

Portable skill package for coding agents. The current skill teaches an agent
how to write, run, and debug Krypton (`.k` / `.ks`) programs without
rediscovering the language, CLI, and common failures every session.

macOS 2.4.9 ships the Objective-K/AppKit table, selection, keyboard, live-field,
column/action, image/menu/frame, lifecycle and text-snapshot APIs described here.
The skill also covers native ABI boundaries, source/install-root selection,
process capture, K-owned models, bundles and release verification. It includes
copyable Krypton starters and a local test runner. Future checkout changes still
need capability checks; Windows/Linux parity is not implied.

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
        ├── macos.md
        ├── macos-ffi.md
        ├── macos-release.md
        ├── language.md
        ├── cli.md
        ├── stdlib.md
        ├── objective-k.md
        ├── appkit-controls.md
        ├── troubleshooting.md
        └── caveman-fallback.md
```

`SKILL.md` is intentionally short. Detailed material lives in `references/`
and is loaded only when needed. `references/objective-k.md` is the deep dive
for native macOS apps, AppKit tables and events, the K-owned runtime, and the
Windows backend differences.

`krypton/assets/macos/` holds data, model, Foundation, process and native-app
examples. From this repository, test against a chosen source or release root:

```sh
KRYPTON_ROOT=/absolute/path/to/krypton bash krypton/scripts/check-macos.sh
```

Add `--bundle` for an ad-hoc bundle check when the root contains the bundler
source. The default test compiles but does not launch the GUI; real interaction
is a separate check. The runner does not install/upgrade the compiler or publish
anything. See `krypton/references/macos.md` for pkg and Homebrew root selection.

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
- Re-test capabilities against both the source checkout and an unpacked release
  with `KRYPTON_ROOT` pinned. Keep fixed 2.4.9 issues separate from older notes.
- Do not claim full platform/ABI/security coverage from compiling a window.
