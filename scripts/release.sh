#!/usr/bin/env bash
#
# Usage: bash scripts/release.sh <version>
# Example: bash scripts/release.sh 1.0.0
##
## Accepts 1.0.0 or v1.0.0 and always normalizes to v-prefixed
## tags and file versions.
##
## Write player notes under '## [Unreleased]' in CHANGELOG.md as you go.
## This script moves them into a dated '## [x.y.z]' section (archiving the
## finished series when a new minor/major opens), bumps the TOC and
## Constants.lua versions, commits, and tags. It refuses to run when
## [Unreleased] is empty, unless the top section already is this version.

set -euo pipefail

INPUT_VERSION="${1:-}"

if [[ -z "$INPUT_VERSION" ]]; then
  echo "Usage: bash scripts/release.sh <version>"
  echo "Example: bash scripts/release.sh 1.0.0"
  exit 1
fi

if ! [[ "$INPUT_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be semver (e.g. 1.0.0 or v1.0.0)"
  exit 1
fi

NORMALIZED_VERSION="${INPUT_VERSION#v}"
TAG_VERSION="v${NORMALIZED_VERSION}"

# Ensure working tree is clean
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# Ensure tag doesn't already exist
if git show-ref --verify --quiet "refs/tags/${TAG_VERSION}"; then
  echo "Error: Tag '${TAG_VERSION}' already exists."
  exit 1
fi

echo "Releasing RaidGroupWrap ${TAG_VERSION}..."

# Fetch live TOC interface numbers from Blizzard's patch CDN, one per flavor
# product. Refuses to release if Retail is unreachable so we never ship a
# stale interface after a WoW patch.
fetch_toc() {
  local product="$1"
  python -c "
import re, sys, urllib.request
try:
    with urllib.request.urlopen('https://us.version.battle.net/v2/products/${product}/versions', timeout=15) as r:
        text = r.read().decode('utf-8', errors='replace')
except Exception as e:
    sys.stderr.write('fetch failed for ${product}: ' + str(e) + '\n')
    sys.exit(1)
for line in text.splitlines():
    if line.startswith('us|'):
        m = re.search(r'\b(\d+)\.(\d+)\.(\d+)\.\d+\b', line)
        if m:
            a, b, c = m.groups()
            print(f'{int(a)}{int(b):02d}{int(c):02d}')
            break
"
}

cdn_die() {
  echo "Error: could not reach https://us.version.battle.net/ for product '$1'."
  echo "       Fix network and retry, or release via GitHub Actions."
  exit 1
}

echo "Fetching live TOC interface numbers from Blizzard CDN..."
TOC_RETAIL=$(fetch_toc wow) || cdn_die wow
# WoW: Forever is soft-fail: the beta lives under 'wow_classic_beta' and the
# launch product key is unknown until 2026-11-04. If the fetch fails, warn and
# keep whatever the TOC currently has.
TOC_FOREVER=$(fetch_toc wow_classic_beta) || true

if [[ -z "$TOC_RETAIL" ]]; then
  echo "Error: could not parse the Retail TOC number from Blizzard response."
  exit 1
fi

echo "  retail (Mainline): ${TOC_RETAIL}"
if [[ -n "$TOC_FOREVER" ]]; then
  echo "  forever:           ${TOC_FOREVER}"
else
  echo "  forever:           skipped (CDN fetch failed, keeping current TOC value)"
fi

# Move [Unreleased] notes into this release's section. Runs before any other
# file edit so a missing-notes error leaves the tree untouched.
python scripts/promote_changelog.py --version "${TAG_VERSION}"

# The Forever client ignores the Interface-Forever line and reads only the
# base line, so Forever's number rides there too (comma list). A failed
# Forever fetch keeps the number already in the TOC.
FOREVER_FOR_BASE="${TOC_FOREVER:-$(grep '^## Interface-Forever:' RaidGroupWrap.toc | grep -o '[0-9][0-9]*' | head -1)}"
sed -i "s/^## Interface: .*/## Interface: ${TOC_RETAIL}${FOREVER_FOR_BASE:+, ${FOREVER_FOR_BASE}}/" RaidGroupWrap.toc
sed -i "s/^## Interface-Mainline: .*/## Interface-Mainline: ${TOC_RETAIL}/" RaidGroupWrap.toc
if [[ -n "$TOC_FOREVER" ]]; then
  sed -i "s/^## Interface-Forever: .*/## Interface-Forever: ${TOC_FOREVER}/" RaidGroupWrap.toc
fi

# Update version in TOC
sed -i "s/^## Version: .*/## Version: ${TAG_VERSION}/" RaidGroupWrap.toc

# Update version in Constants.lua
sed -i "s/VERSION = \"[^\"]*\"/VERSION = \"${TAG_VERSION}\"/" Core/Constants.lua

# Commit version + interface bump
git add RaidGroupWrap.toc Core/Constants.lua CHANGELOG.md
if [[ -d archive/changelog ]]; then
  git add archive/changelog
fi
if git diff --cached --quiet; then
  echo "No TOC or version changes to commit (already up to date)."
else
  git commit -m "release: ${TAG_VERSION}"
fi

# Create annotated tag
git tag -a "${TAG_VERSION}" -m "Release ${TAG_VERSION}"

echo ""
echo "Version bumped and tag created."
echo ""
echo "To publish, push the tag:"
echo "  git push origin master ${TAG_VERSION}"
echo ""
echo "This will trigger the CI pipeline which:"
echo "  1. Runs lint checks"
echo "  2. Packages the addon"
echo "  3. Uploads to CurseForge"
echo "  4. Creates a GitHub Release"
