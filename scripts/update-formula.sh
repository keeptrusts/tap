#!/usr/bin/env bash
# Pulls the latest release manifest and updates Formula/kt.rb.
#
# Usage:
#   ./scripts/update-formula.sh [--push]
#   KEEPTRUSTS_MANIFEST_URL=https://dl.eu.keeptrusts.com/releases/latest/manifest.json ./scripts/update-formula.sh
#
# The manifest is fetched from each regional download CDN and merged so that
# all platform hashes are available even when a region only built a subset
# (e.g. Linux-only from the container build, macOS from a host build).

set -euo pipefail

DOWNLOAD_BASE="${KEEPTRUSTS_DOWNLOAD_BASE:-https://dl.eu.keeptrusts.com}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FORMULA="${TAP_ROOT}/Formula/kt.rb"
DO_PUSH=false

MANIFEST_URLS="${KEEPTRUSTS_MANIFEST_URL:-https://dl.eu.keeptrusts.com/releases/latest/manifest.json,https://dl.us.keeptrusts.com/releases/latest/manifest.json}"

for arg in "$@"; do
    case "$arg" in
        --push) DO_PUSH=true ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required" >&2; exit 1
fi

merged_manifest=""
IFS=',' read -ra urls <<< "$MANIFEST_URLS"
for url in "${urls[@]}"; do
    echo "Fetching manifest from ${url}"
    body="$(curl -fsSL "$url" 2>/dev/null || true)"
    if [ -n "$body" ]; then
        if [ -z "$merged_manifest" ]; then
            merged_manifest="$body"
        else
            merged_manifest="$(printf '%s\n%s' "$merged_manifest" "$body" | python3 -c "
import sys, json
manifests = [json.loads(line) for line in sys.stdin if line.strip()]
merged = manifests[0]
seen = {a['filename'] for a in merged['artifacts']}
for m in manifests[1:]:
    for a in m['artifacts']:
        if a['filename'] not in seen:
            merged['artifacts'].append(a)
            seen.add(a['filename'])
print(json.dumps(merged))
")"
        fi
    fi
done

if [ -z "$merged_manifest" ]; then
    echo "error: could not fetch any manifest" >&2; exit 1
fi

sha_for() {
    printf '%s' "$merged_manifest" | python3 -c "
import sys, json
for a in json.load(sys.stdin)['artifacts']:
    if a['filename'] == '$1':
        print(a['sha256']); sys.exit(0)
print('')
"
}

VERSION="$(printf '%s' "$merged_manifest" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")"
SHA_MACOS="$(sha_for "kt-macos-universal.tar.gz")"
SHA_LINUX_X86="$(sha_for "kt-linux-x86_64.tar.gz")"
SHA_LINUX_ARM="$(sha_for "kt-linux-aarch64.tar.gz")"

echo "Version: ${VERSION}"
echo "  macOS universal : ${SHA_MACOS:-MISSING}"
echo "  Linux x86_64    : ${SHA_LINUX_X86:-MISSING}"
echo "  Linux aarch64   : ${SHA_LINUX_ARM:-MISSING}"

if [ -z "$VERSION" ]; then
    echo "error: could not extract version from manifest" >&2; exit 1
fi

# Keep existing hash if the manifest doesn't include a platform
existing_sha() {
    local pattern="$1"
    grep -A1 "$pattern" "$FORMULA" 2>/dev/null | grep sha256 | sed 's/.*"\(.*\)".*/\1/' || true
}
[ -z "$SHA_MACOS" ] && SHA_MACOS="$(existing_sha 'macos-universal')"
[ -z "$SHA_LINUX_X86" ] && SHA_LINUX_X86="$(existing_sha 'linux-x86_64')"
[ -z "$SHA_LINUX_ARM" ] && SHA_LINUX_ARM="$(existing_sha 'linux-aarch64')"

if [ -z "$SHA_LINUX_X86" ] || [ -z "$SHA_LINUX_ARM" ]; then
    echo "error: missing required Linux SHA256 hashes" >&2; exit 1
fi

cat > "$FORMULA" <<RUBY
class Kt < Formula
  desc "Keeptrusts AI governance gateway CLI"
  homepage "https://keeptrusts.com"
  license :cannot_represent
  version "${VERSION}"

  on_macos do
    url "${DOWNLOAD_BASE}/releases/#{version}/kt-macos-universal.tar.gz"
    sha256 "${SHA_MACOS}"
  end

  on_linux do
    if Hardware::CPU.arm?
      url "${DOWNLOAD_BASE}/releases/#{version}/kt-linux-aarch64.tar.gz"
      sha256 "${SHA_LINUX_ARM}"
    else
      url "${DOWNLOAD_BASE}/releases/#{version}/kt-linux-x86_64.tar.gz"
      sha256 "${SHA_LINUX_X86}"
    end
  end

  def install
    bin.install "kt"
  end

  test do
    assert_match "kt", shell_output("#{bin}/kt --version")
  end
end
RUBY

cd "$TAP_ROOT"
git add Formula/kt.rb
if git diff --cached --quiet; then
    echo "Formula already up to date (${VERSION})"
    exit 0
fi

git commit -m "kt ${VERSION}"
echo "Committed: kt ${VERSION}"

if [ "$DO_PUSH" = true ]; then
    git push origin HEAD
    echo "Pushed to origin"
fi
