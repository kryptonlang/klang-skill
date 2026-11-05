#!/usr/bin/env bash
# Install the Krypton agent skill for OpenCode, Claude Code, Codex, and Freebuff.
#
# Default: symlink the skill into each agent's global skills directory.
# Re-run safely; existing unrelated entries are left alone unless --force.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$HERE/krypton"
SKILL_NAME="krypton"
CAVEMAN_NAME="caveman"

SCOPE="global"
PROJECT_DIR="$PWD"
COPY=0
FORCE=0
DRY_RUN=0
UNINSTALL=0
WITH_CAVEMAN="auto"
CAVEMAN_SRC=""
AGENTS="opencode,claude,codex,freebuff"

usage() {
    cat <<'EOF'
Install the Krypton skill for coding agents.

Usage:
  ./install.sh [options]

Options:
  --global                 Install for the current user (default)
  --project [DIR]          Install into a project instead (default: $PWD)
  --agents LIST            Comma list: opencode,claude,codex,freebuff
                           Default: all four
  --copy                   Copy files instead of creating symlinks
  --force                  Replace an existing krypton/caveman entry
  --with-caveman [PATH]    Also install the caveman companion skill
                           PATH defaults to ~/Documents/caveman-main/skills/caveman
  --no-caveman             Do not install the caveman companion
  --uninstall              Remove entries created by this installer
  --dry-run                Print actions without changing files
  -h, --help               Show this help

Global targets:
  OpenCode   ~/.config/opencode/skills
  Claude     ~/.claude/skills
  Codex      ~/.codex/skills
  Freebuff   ~/.agents/skills

Project targets:
  OpenCode   <project>/.opencode/skills
  Claude     <project>/.claude/skills
  Codex      <project>/.codex/skills
  Freebuff   <project>/.agents/skills

The Krypton skill loads the caveman skill when available. Auto mode installs
caveman only for OpenCode and Freebuff, because Claude Code and Codex normally
already get it as a plugin.
EOF
}

need_arg() {
    if [[ $# -lt 2 || "$2" == -* ]]; then
        echo "install.sh: $1 needs a value" >&2
        exit 2
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --global)
            SCOPE="global"
            shift
            ;;
        --project)
            SCOPE="project"
            shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                PROJECT_DIR="$1"
                shift
            fi
            ;;
        --agents)
            need_arg "$@" || exit 2
            AGENTS="$2"
            shift 2
            ;;
        --copy)
            COPY=1
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --with-caveman)
            WITH_CAVEMAN="all"
            shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                CAVEMAN_SRC="$1"
                shift
            fi
            ;;
        --no-caveman)
            WITH_CAVEMAN="off"
            shift
            ;;
        --uninstall)
            UNINSTALL=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "install.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -d "$SOURCE" ]]; then
    echo "install.sh: missing skill directory: $SOURCE" >&2
    exit 1
fi

if [[ "$SCOPE" == "project" ]]; then
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
fi

agent_supported() {
    case ",$AGENTS," in
        *,"$1",*) return 0 ;;
        *) return 1 ;;
    esac
}

target_dir() {
    local agent="$1"
    if [[ "$SCOPE" == "global" ]]; then
        case "$agent" in
            opencode) echo "$HOME/.config/opencode/skills" ;;
            claude)   echo "$HOME/.claude/skills" ;;
            codex)    echo "$HOME/.codex/skills" ;;
            freebuff) echo "$HOME/.agents/skills" ;;
            *) return 1 ;;
        esac
    else
        case "$agent" in
            opencode) echo "$PROJECT_DIR/.opencode/skills" ;;
            claude)   echo "$PROJECT_DIR/.claude/skills" ;;
            codex)    echo "$PROJECT_DIR/.codex/skills" ;;
            freebuff) echo "$PROJECT_DIR/.agents/skills" ;;
            *) return 1 ;;
        esac
    fi
}

run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf 'would:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

install_one() {
    local src="$1" name="$2" dest_root="$3"
    local dest="$dest_root/$name"

    if [[ -L "$dest" ]]; then
        if [[ "$(readlink "$dest")" == "$src" ]]; then
            echo "  ok    $dest"
            return 0
        fi
        if [[ "$FORCE" != "1" ]]; then
            echo "  skip  $dest (different symlink; use --force)"
            return 0
        fi
        run rm -f "$dest"
    elif [[ -e "$dest" ]]; then
        if [[ "$FORCE" != "1" ]]; then
            echo "  skip  $dest (exists; use --force)"
            return 0
        fi
        run rm -rf "$dest"
    fi

    run mkdir -p "$dest_root"
    if [[ "$COPY" == "1" ]]; then
        run cp -R "$src" "$dest"
        echo "  copy  $dest"
    else
        run ln -s "$src" "$dest"
        echo "  link  $dest"
    fi
}

uninstall_one() {
    local src="$1" name="$2" dest_root="$3"
    local dest="$dest_root/$name"

    if [[ -L "$dest" ]]; then
        local link
        link="$(readlink "$dest")"
        if [[ "$link" == "$src" || "$FORCE" == "1" ||
              ( -z "$src" && "$(basename "$link")" == "$name" ) ]]; then
            run rm -f "$dest"
            echo "  rm    $dest"
        else
            echo "  skip  $dest (not this installer; use --force)"
        fi
    elif [[ -d "$dest" && "$FORCE" == "1" ]]; then
        run rm -rf "$dest"
        echo "  rm    $dest"
    elif [[ -e "$dest" ]]; then
        echo "  skip  $dest (copy or unrelated entry; use --force)"
    else
        echo "  none  $dest"
    fi
}

caveman_source() {
    if [[ -n "$CAVEMAN_SRC" ]]; then
        echo "$CAVEMAN_SRC"
        return 0
    fi
    local candidates=(
        "$HOME/Documents/caveman-main/skills/caveman"
        "$HOME/caveman/skills/caveman"
        "$HOME/src/caveman/skills/caveman"
    )
    local c
    for c in "${candidates[@]}"; do
        if [[ -f "$c/SKILL.md" ]]; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

echo "Krypton skill installer"
echo "  source: $SOURCE"
echo "  scope:  $SCOPE"
if [[ "$SCOPE" == "project" ]]; then
    echo "  project: $PROJECT_DIR"
fi

if [[ "$UNINSTALL" == "1" ]]; then
    for agent in opencode claude codex freebuff; do
        agent_supported "$agent" || continue
        root="$(target_dir "$agent")"
        echo "$agent:"
        uninstall_one "$SOURCE" "$SKILL_NAME" "$root"
        uninstall_one "" "$CAVEMAN_NAME" "$root"
    done
    exit 0
fi

if [[ "$WITH_CAVEMAN" != "off" ]]; then
    if ! CAVEMAN_PATH="$(caveman_source)"; then
        echo "install.sh: caveman source not found; skipping companion" >&2
        echo "           pass --with-caveman /path/to/caveman or --no-caveman" >&2
        WITH_CAVEMAN="off"
    else
        echo "  caveman: $CAVEMAN_PATH"
    fi
fi

for agent in opencode claude codex freebuff; do
    agent_supported "$agent" || continue
    root="$(target_dir "$agent")"
    echo "$agent:"
    install_one "$SOURCE" "$SKILL_NAME" "$root"

    if [[ "$WITH_CAVEMAN" == "all" ]]; then
        install_one "$CAVEMAN_PATH" "$CAVEMAN_NAME" "$root"
    elif [[ "$WITH_CAVEMAN" == "auto" ]]; then
        case "$agent" in
            opencode|freebuff)
                install_one "$CAVEMAN_PATH" "$CAVEMAN_NAME" "$root"
                ;;
            *)
                echo "  note  caveman normally ships as a $agent plugin; use --with-caveman to add a skill copy"
                ;;
        esac
    fi
done

echo
echo "Done. Restart or reload the agent if it does not discover the skill."
echo "Try: \"use the krypton skill\" or /skill:krypton."
