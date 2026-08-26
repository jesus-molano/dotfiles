#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d)
trap 'find "$test_root" -depth -delete' EXIT
mkdir -p "$test_root/bin" "$test_root/release/CodexBar_CodexBarCore.bundle" "$test_root/output"

cat >"$test_root/release/CodexBarCLI" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --version ]]; then
	printf '%s\n' 'CodexBar 0.55.1'
else
	printf '%s\n' '[{"provider":"codex","error":null,"usage":{"secondary":{}}}]'
fi
EOF
chmod +x "$test_root/release/CodexBarCLI"
ln -s CodexBarCLI "$test_root/release/codexbar"
printf '%s\n' '0.55.1' >"$test_root/release/VERSION"
printf '%s\n' 'fixture' >"$test_root/release/CodexBar_CodexBarCore.bundle/Info.plist"
tar -czf "$test_root/CodexBarCLI-v0.55.1-linux-x86_64.tar.gz" -C "$test_root/release" .
(
	cd "$test_root"
	sha256sum CodexBarCLI-v0.55.1-linux-x86_64.tar.gz \
		>CodexBarCLI-v0.55.1-linux-x86_64.tar.gz.sha256
)

cat >"$test_root/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $* == *'/releases/latest' ]]; then
	printf '%s\n' '{"tag_name":"v0.55.1"}'
	exit 0
fi
destination=''
url=${!#}
while (($#)); do
	if [[ $1 == -o ]]; then
		destination=$2
		shift 2
	else
		shift
	fi
done
[[ -n $destination ]]
cp "$TEST_ROOT/${url##*/}" "$destination"
EOF

cat >"$test_root/bin/pacman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $* == '-Q codexbar-cli' ]]
printf '%s\n' 'codexbar-cli 0.53.0-1'
EOF

cat >"$test_root/bin/shelly" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$TEST_ROOT/shelly.call"
: >codexbar-cli-0.55.1-1-x86_64.pkg.tar.zst
EOF
chmod +x "$test_root/bin/"*

common_env=(
	TEST_ROOT="$test_root"
	CURL_BIN="$test_root/bin/curl"
	PACMAN_BIN="$test_root/bin/pacman"
	SHELLY_BIN="$test_root/bin/shelly"
	CODEXBAR_GITHUB_API='https://example.test/releases/latest'
	CODEXBAR_RELEASE_BASE='https://example.test/releases/download'
	CODEXBAR_PACKAGE_OUTPUT_DIR="$test_root/output"
)

grep -Fxq "depends=('curl' 'gcc-libs' 'glibc' 'sqlite')" \
	"$repo_root/packages/codexbar-cli/PKGBUILD"

env "${common_env[@]}" "$repo_root/scripts/codexbar-official" check >"$test_root/check.out"
grep -Fxq 'Instalado: 0.53.0-1' "$test_root/check.out"
grep -Fxq 'Receta:    0.55.1' "$test_root/check.out"
grep -Fxq 'Upstream:  0.55.1' "$test_root/check.out"
grep -Fxq 'Estado: hay una actualización disponible.' "$test_root/check.out"

env "${common_env[@]}" "$repo_root/scripts/codexbar-official" test >"$test_root/test.out"
grep -Fxq 'PASS: CodexBar 0.55.1 verificó el checksum y devolvió uso válido.' "$test_root/test.out"

env "${common_env[@]}" "$repo_root/scripts/codexbar-official" build >"$test_root/build.out"
grep -Fxq 'build PKGBUILD --reviewed --check' "$test_root/shelly.call"
[[ -f $test_root/output/codexbar-cli-0.55.1-1-x86_64.pkg.tar.zst ]]

printf '%s\n' 'PASS: comprobación, prueba y construcción oficial de CodexBar'
