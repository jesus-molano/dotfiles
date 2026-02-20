#!/usr/bin/env bash
# PostToolUse hook: auto-format files after Write|Edit
# Reads tool_input.file_path from stdin JSON, formats with Biome or Prettier

set -euo pipefail

# Read hook input from stdin
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
[[ -z "$file_path" ]] && exit 0

# Skip non-formattable files
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.vue|*.json|*.jsonc|*.css|*.scss|*.html|*.md|*.yaml|*.yml)
    ;;
  *)
    exit 0
    ;;
esac

# Skip if file doesn't exist
[[ ! -f "$file_path" ]] && exit 0

# Find project root (look for package.json)
dir=$(dirname "$file_path")
project_root=""
while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/package.json" ]]; then
    project_root="$dir"
    break
  fi
  dir=$(dirname "$dir")
done

# No project root found — skip
[[ -z "$project_root" ]] && exit 0

# Format with Biome if config exists, otherwise Prettier if config exists
if [[ -f "$project_root/biome.json" ]] || [[ -f "$project_root/biome.jsonc" ]]; then
  npx biome format --write "$file_path" 2>/dev/null || true
elif [[ -f "$project_root/.prettierrc" ]] || [[ -f "$project_root/.prettierrc.json" ]] || \
     [[ -f "$project_root/.prettierrc.js" ]] || [[ -f "$project_root/.prettierrc.cjs" ]] || \
     [[ -f "$project_root/.prettierrc.mjs" ]] || [[ -f "$project_root/.prettierrc.yml" ]] || \
     [[ -f "$project_root/.prettierrc.yaml" ]] || [[ -f "$project_root/.prettierrc.toml" ]] || \
     [[ -f "$project_root/prettier.config.js" ]] || [[ -f "$project_root/prettier.config.cjs" ]] || \
     [[ -f "$project_root/prettier.config.mjs" ]]; then
  npx prettier --write "$file_path" 2>/dev/null || true
fi

exit 0
