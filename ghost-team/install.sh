#!/usr/bin/env bash
#
# Install the Ghost Team into a project (or your home directory).
#
# Usage:
#   ./install.sh            # install into ./.claude (the current project)
#   ./install.sh --global   # install into ~/.claude (every project you open)
#   ./install.sh /path/to/project
#
# It copies the agents and slash commands into the target's .claude/ folder.
# Re-running it updates them. Your own agents/commands are left untouched
# unless they share a filename with one of ours.

set -euo pipefail

# Where this script lives — so it works no matter where you run it from.
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve the target .claude directory.
case "${1:-}" in
  --global|-g)
    TARGET="$HOME/.claude"
    ;;
  "")
    TARGET="$(pwd)/.claude"
    ;;
  *)
    TARGET="${1%/}/.claude"
    ;;
esac

echo "✦ Installing the Ghost Team into: $TARGET"

mkdir -p "$TARGET/agents" "$TARGET/commands"
cp "$SRC_DIR/agents/"*.md "$TARGET/agents/"
cp "$SRC_DIR/commands/"*.md "$TARGET/commands/"

agent_count=$(ls -1 "$SRC_DIR/agents/"*.md | wc -l | tr -d ' ')
cmd_count=$(ls -1 "$SRC_DIR/commands/"*.md | wc -l | tr -d ' ')

echo "  → $agent_count agents and $cmd_count slash commands installed."
echo ""
echo "Next: open Claude Code in that project and try:"
echo "    /standup        plan your day and delegate it"
echo "    /ship <idea>    take something from concept to shipped"
echo "    /validate <idea> pressure-test before you build"
echo ""
echo "Or just talk to a teammate by name, e.g.:"
echo '    "ask the growth-marketer to write a Show HN post for X"'
echo ""
echo "Run /agents inside Claude Code to see and edit the team. Done. ✦"
