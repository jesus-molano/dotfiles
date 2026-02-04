#!/usr/bin/env bash
# Re-inject critical rules after context compaction
cat << 'RULES'
CRITICAL REMINDERS:
1. NEVER add Co-Authored-By or AI attribution to commits
2. Detect package manager from lockfile before running install/add commands
3. Use Context7 MCP for framework docs before coding
RULES
exit 0
