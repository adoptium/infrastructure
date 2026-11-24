#!/bin/bash
# Work out which DockerStatic Dockerfiles need building and emit a GitHub Actions matrix.
#
# Rules:
#   * Only changed Dockerfile.* files are selected, unless
#   * any other file in the DockerStatic role (or this CI workflow) changed, in which case all are selected.
#   * Deleted Dockerfiles are not built, but deleting any other file in the role still selects all.
#
# Usage:   select_dockerfiles.sh <base-ref> [head-ref]      (head-ref defaults to HEAD)
# Output:  a compact JSON array on stdout: [{"name":"u2404","runner":"ubuntu-latest"}, ...]
#          Set GITHUB_OUTPUT (done automatically by GitHub Actions) to also write matrix=<json>.
#
# Works locally and in GitHub Actions. Requires git and jq.

set -eu -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <base-ref> [head-ref]" >&2
    exit 2
fi
base="$1"
head="${2:-HEAD}"

ROLE_DIR="ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic"
DOCKERFILE_DIR="$ROLE_DIR/Dockerfiles"
WORKFLOW=".github/workflows/check_dockerstatic.yml"

# Dockerfiles that download an aarch64 JDK need an arm64 runner, everything else is x64.
X64_RUNNER="${X64_RUNNER:-ubuntu-latest}"
ARM64_RUNNER="${ARM64_RUNNER:-ubuntu-24.04-arm}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

all_dockerfiles() {
    # Names (without the Dockerfile. prefix) of every Dockerfile present in the head revision.
    git ls-tree --name-only "$head" "$DOCKERFILE_DIR/" | sed -n 's|.*/Dockerfile\.||p'
}

# Three-dot diff: changes on the head side since it diverged from base, as a PR shows them.
changed_files="$(git diff --name-only "$base...$head" -- "$ROLE_DIR" "$WORKFLOW")"

build_all=false
selected=""
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$file" == "$DOCKERFILE_DIR"/Dockerfile.* ]]; then
        # A deleted Dockerfile has nothing left to build, so only select ones present in the head revision.
        if git cat-file -e "$head:$file" 2>/dev/null; then
            selected+="${file##*/Dockerfile.}"$'\n'
        fi
    else
        # Anything else in the role (tasks, scripts, README...) or the workflow itself.
        build_all=true
    fi
done <<< "$changed_files"

if $build_all; then
    selected="$(all_dockerfiles)"
fi

matrix="[]"
while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    runner="$X64_RUNNER"
    if git show "$head:$DOCKERFILE_DIR/Dockerfile.$name" | grep -qE '/linux/aarch64/|architecture=aarch64'; then
        runner="$ARM64_RUNNER"
    fi
    matrix="$(jq -c --arg name "$name" --arg runner "$runner" '. + [{name: $name, runner: $runner}]' <<< "$matrix")"
done < <(sort -u <<< "$selected")

echo "build_all=$build_all" >&2
echo "$matrix"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "matrix=$matrix"
        echo "count=$(jq length <<< "$matrix")"
    } >> "$GITHUB_OUTPUT"
fi
