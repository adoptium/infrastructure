#!/bin/bash
# regenContainers.sh
# Detects running Adoptium static Docker containers and matches each one to its
# Dockerfile.  Later phases (stop/kill/rebuild/rerun) will be added on top.
set -euo pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_DIR="${SCRIPT_DIR}/../Dockerfiles"

# ---------------------------------------------------------------------------
# detect_containers
# Populates the parallel arrays:
#   CONTAINER_IDS   – short container ID
#   CONTAINER_NAMES – container name as assigned by deploy.yml (e.g. U2404.32001)
#   IMAGE_TAGS      – lowercase image tag extracted from the name  (e.g. u2404)
#   DOCKERFILES     – absolute path to the matching Dockerfile, or "" if none found
# ---------------------------------------------------------------------------
detect_containers() {
    # Read every running container that was built from an aqa_* image.
    # docker ps output: <id> <image> <name>
    while IFS=$'\t' read -r cid image cname; do
        # Only process containers whose image name starts with "aqa_"
        if [[ "$image" != aqa_* ]]; then
            continue
        fi

        # Derive the lowercase tag from the image name: "aqa_u2404" -> "u2404"
        # Strip the optional .arm32 suffix from the image name before mapping.
        raw_tag="${image#aqa_}"          # e.g. "u2404" or "u2404.arm32"
        image_tag="${raw_tag%.arm32}"    # strip trailing .arm32 if present

        # Locate the corresponding Dockerfile
        dockerfile="${DOCKERFILE_DIR}/Dockerfile.${image_tag}"
        if [[ ! -f "$dockerfile" ]]; then
            dockerfile=""
        fi

        CONTAINER_IDS+=("$cid")
        CONTAINER_NAMES+=("$cname")
        IMAGE_TAGS+=("$image_tag")
        DOCKERFILES+=("$dockerfile")
    done < <(docker ps --format $'{{.ID}}\t{{.Image}}\t{{.Names}}')
}

# ---------------------------------------------------------------------------
# print_matches
# Prints a human-readable summary of every detected container and its
# matched Dockerfile (or a warning when no match is found).
# ---------------------------------------------------------------------------
print_matches() {
    local count="${#CONTAINER_IDS[@]}"

    if [[ "$count" -eq 0 ]]; then
        echo "No running Adoptium containers found."
        return
    fi

    echo "Found ${count} running Adoptium container(s):"
    echo "------------------------------------------------------------------------"
    printf "%-14s  %-28s  %-10s  %s\n" "CONTAINER ID" "NAME" "IMAGE TAG" "DOCKERFILE"
    echo "------------------------------------------------------------------------"

    for i in "${!CONTAINER_IDS[@]}"; do
        local df="${DOCKERFILES[$i]}"
        if [[ -z "$df" ]]; then
            df="(no matching Dockerfile found)"
        else
            # Print path relative to DOCKERFILE_DIR for readability
            df="Dockerfiles/$(basename "$df")"
        fi
        printf "%-14s  %-28s  %-10s  %s\n" \
            "${CONTAINER_IDS[$i]}" \
            "${CONTAINER_NAMES[$i]}" \
            "${IMAGE_TAGS[$i]}" \
            "$df"
    done
    echo "------------------------------------------------------------------------"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
declare -a CONTAINER_IDS=()
declare -a CONTAINER_NAMES=()
declare -a IMAGE_TAGS=()
declare -a DOCKERFILES=()

detect_containers
print_matches
