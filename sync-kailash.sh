#!/bin/bash
# sync-kailash.sh — Sync Kailash COC Claude (Python) from subtree into project
#
# Usage:
#   ./sync-kailash.sh              # Dry run (show what would change)
#   ./sync-kailash.sh --apply      # Actually sync files
#   ./sync-kailash.sh --pull       # Pull latest from upstream, then dry run
#   ./sync-kailash.sh --pull --apply  # Pull latest and sync
#
# This script syncs framework files from kailash-setup/ (git subtree)
# into the project's working directories (.claude/, scripts/, etc.).
#
# It will NOT overwrite:
#   - Root CLAUDE.md (project-specific — shows diff instead)
#   - .claude/learning/ (project-specific observations/instincts)
#   - Any file not present in the upstream subtree

set -euo pipefail

SUBTREE_DIR="kailash-setup"
APPLY=false
PULL=false

for arg in "$@"; do
  case $arg in
    --apply) APPLY=true ;;
    --pull)  PULL=true ;;
    --help|-h)
      echo "Usage: $0 [--pull] [--apply]"
      echo "  --pull   Pull latest from upstream before syncing"
      echo "  --apply  Actually apply changes (default is dry run)"
      exit 0
      ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

# Ensure we're in the repo root
if [ ! -d "$SUBTREE_DIR" ]; then
  echo "Error: $SUBTREE_DIR/ not found. Run from the repo root."
  exit 1
fi

# Pull latest if requested
if $PULL; then
  echo "==> Pulling latest from upstream..."
  git subtree pull --prefix="$SUBTREE_DIR" \
    https://github.com/Integrum-Global/kailash-coc-claude-py.git main --squash
  echo ""
fi

# Directories to sync (source relative to subtree -> destination relative to repo root)
# Format: "subtree_path:dest_path"
SYNC_DIRS=(
  ".claude/agents:.claude/agents"
  ".claude/commands:.claude/commands"
  ".claude/guides:.claude/guides"
  ".claude/rules:.claude/rules"
  ".claude/skills:.claude/skills"
  "scripts/hooks:scripts/hooks"
  "scripts/ci:scripts/ci"
  "scripts/learning:scripts/learning"
  "scripts/plugin:scripts/plugin"
  "sdk-users:sdk-users"
  "mcp-configs:mcp-configs"
  "tests:tests"
  "workspaces/_template:workspaces/_template"
)

# Individual files to sync
SYNC_FILES=(
  ".claude/settings.json:.claude/settings.json"
  "workspaces/README.md:workspaces/README.md"
  "workspaces/CLAUDE.md:workspaces/CLAUDE.md"
)

# Build rsync flags
# No --delete: project-specific files (custom agents, renamed guides, etc.)
# are preserved. Only upstream files are added or updated.
if $APPLY; then
  echo "==> APPLYING changes..."
  RSYNC_FLAGS="-av"
else
  echo "==> DRY RUN (use --apply to actually sync)"
  RSYNC_FLAGS="-avn"
fi

CHANGES_FOUND=false

# Sync directories
for mapping in "${SYNC_DIRS[@]}"; do
  SRC="${SUBTREE_DIR}/${mapping%%:*}/"
  DST="${mapping##*:}/"

  if [ ! -d "$SRC" ]; then
    continue
  fi

  # Ensure destination parent exists
  if $APPLY; then
    mkdir -p "$DST"
  fi

  OUTPUT=$(rsync $RSYNC_FLAGS "$SRC" "$DST" 2>&1 || true)

  # Check if there are actual changes (not just directory listings)
  if echo "$OUTPUT" | grep -qE '^(deleting |>f|cf|cd)'; then
    CHANGES_FOUND=true
    echo ""
    echo "--- ${mapping##*:} ---"
    echo "$OUTPUT" | grep -vE '^(sending|receiving|total|sent |$|building file list|\./$)'
  fi
done

# Sync individual files
for mapping in "${SYNC_FILES[@]}"; do
  SRC="${SUBTREE_DIR}/${mapping%%:*}"
  DST="${mapping##*:}"

  if [ ! -f "$SRC" ]; then
    continue
  fi

  if $APPLY; then
    mkdir -p "$(dirname "$DST")"
  fi

  if [ ! -f "$DST" ] || ! diff -q "$SRC" "$DST" > /dev/null 2>&1; then
    CHANGES_FOUND=true
    echo ""
    echo "--- ${mapping##*:} ---"
    if $APPLY; then
      cp "$SRC" "$DST"
      echo "  updated"
    else
      echo "  would update"
      diff --brief "$SRC" "$DST" 2>/dev/null || echo "  (new file)"
    fi
  fi
done

# Always show CLAUDE.md diff but never auto-sync it
if ! diff -q "${SUBTREE_DIR}/CLAUDE.md" "CLAUDE.md" > /dev/null 2>&1; then
  CHANGES_FOUND=true
  echo ""
  echo "--- CLAUDE.md (NOT auto-synced — project-specific) ---"
  echo "  Upstream CLAUDE.md differs from yours."
  echo "  Review with:  diff ${SUBTREE_DIR}/CLAUDE.md CLAUDE.md"
  echo "  Or merge manually."
fi

# Preserve project-specific .claude/learning/ if it exists
if [ -d ".claude/learning" ]; then
  echo ""
  echo "--- .claude/learning/ (preserved — project-specific) ---"
fi

echo ""
if $CHANGES_FOUND; then
  if $APPLY; then
    echo "Sync complete."
  else
    echo "Changes found. Run with --apply to sync."
  fi
else
  echo "Everything is up to date."
fi
