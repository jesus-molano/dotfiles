#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/start-noctalia-ready"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat >"$test_root/bin/appearance-switch" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'appearance:%s\n' "$*" >>"$TEST_LOG"
[[ $* == prepare ]]
EOF

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'noctalia:%s\n' "$*" >>"$TEST_LOG"
[[ $* == 'msg status' ]]
EOF

chmod +x "$test_root/bin/appearance-switch" "$test_root/bin/noctalia"
PATH="$test_root/bin:$PATH" TEST_LOG="$test_root/log" "$helper"

[[ $(<"$test_root/log") == $'appearance:prepare\nnoctalia:msg status' ]]
printf '%s\n' 'PASS: Noctalia prepara la colección visible antes de consultar la instancia'
