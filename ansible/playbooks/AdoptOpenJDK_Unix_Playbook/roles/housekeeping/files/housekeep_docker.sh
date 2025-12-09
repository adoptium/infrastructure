#!/bin/sh
#
# housekeep_docker.sh
#
# Modes
#   · CHECK  (default) : reports only
#   · DELETE           : actually removes items
#
# Built-in exclusions:
#   Images whose repository:tag **begins** with any word in DEFAULT_EXCLUDES
#   are always kept, together with the containers built from them.
#
#   You can add more prefixes at run-time:
#     --exclude aqa_                  (single prefix)
#     --exclude aqa_,foo_,bar-        (comma list)
#     -x adoptopenjdk -x scratch_     (repeatable)
#
# Examples
#   ./housekeep_docker.sh
#   ./housekeep_docker.sh delete --exclude mytest_
#   ./housekeep_docker.sh -x foo_ -x bar_           # dry-run
#
##########################################################

set -eu

##########################################################
# 0.  Default exclusions and argument parsing
##########################################################
DEFAULT_EXCLUDES="aqa_ adoptopenjdk"   # <-- edit this list to suit
EXCLUDE_PREFIXES="$DEFAULT_EXCLUDES"
ACTION="check"

add_prefixes() {
    # Accept comma-separated lists or single words
    for p in $(printf '%s\n' "$1" | tr ',' ' '); do
        [ -n "$p" ] && EXCLUDE_PREFIXES="$EXCLUDE_PREFIXES $p"
    done
}

while [ $# -gt 0 ]; do
    case "$1" in
        delete|-d|--delete) ACTION="delete" ;;
        check|-c|--check)   ACTION="check"  ;;
        --exclude=*|-x=*)   add_prefixes "${1#*=}" ;;
        --exclude|-x)       shift; add_prefixes "${1:-}";;
        *) printf >&2 'Usage: %s [check|delete] [--exclude PREFIX]\n' "$0"; exit 2 ;;
    esac
    shift
done

# Deduplicate prefixes
EXCLUDE_PREFIXES=$(printf '%s\n' $EXCLUDE_PREFIXES | awk '!a[$0]++')

printf '\n=== MODE  : %s ===\n' "$ACTION"
printf '=== KEEP  : %s ===\n\n' "$EXCLUDE_PREFIXES"

##########################################################
# Detect Docker / Podman
##########################################################
CLI=docker
if ! command -v docker >/dev/null 2>&1; then
    if command -v podman >/dev/null 2>&1; then
        CLI=podman
    else
        echo "Neither docker nor podman found in PATH." >&2
        exit 1
    fi
fi

# Podman compatibility - requires crun to be present on a podman system
EXTRA_ARGS=""
if [ "$CLI" = "podman" ]; then
    for R in /usr/bin/runc /usr/bin/crun; do [ -x "$R" ] && OCI="$R" && break; done
    [ -z "${OCI:-}" ] && { echo "No OCI runtime found for Podman."; exit 1; }
    EXTRA_ARGS="--runtime=$OCI"
    echo "Using Podman with runtime $OCI"
fi

# Check the version of docker has "until" support
check_until_filter_support() {
    # Try a harmless command using "until", suppress output
    if ! $CLI images --filter "until=1h" --format '{{.Repository}}' >/dev/null 2>&1; then
        echo "Warning: $CLI does not support '--filter until=...'. Falling back to no age filtering."
        return 1
    fi
    return 0
}

if check_until_filter_support; then
    USE_UNTIL_FILTER=true
else
    USE_UNTIL_FILTER=false
fi

##########################################################
# 2. Helper Functions
##########################################################

run() {                      # run sub-command or echo in CHECK mode
    if [ "$ACTION" = "check" ]; then
        printf 'Would run: %s %s %s\n' "$CLI" "$*" "$EXTRA_ARGS"
    else
        # shellcheck disable=SC2086
        $CLI $* $EXTRA_ARGS
    fi
}

prefix_match() {             # prefix_match STRING  → 0 if matches any exclude
    s=$1
    for p in $EXCLUDE_PREFIXES; do
        case "$s" in ${p}*) return 0;; esac
    done
    return 1
}

check_until_filter_support() {
    # Try a harmless command using "until", suppress output
    if ! $CLI images --filter "until=1h" --format '{{.Repository}}' >/dev/null 2>&1; then
        echo "Warning: $CLI does not support '--filter until=...'. Falling back to no age filtering."
        return 1
    fi
    return 0
}
# Define Default Time Period Macros For CLI

SIX_MONTHS=4320h
TWO_WEEKS=336h
ONE_WEEK=168h
FIVE_DAYS=120h
THREE_DAYS=72h

# Define Macros For Temp files
IMAGES=$(mktemp)
CONTAINERS=$(mktemp)
OLD_CONTAINERS=$(mktemp)

trap 'rm -f "$IMAGES" "$CONTAINERS" "$OLD_CONTAINERS"' EXIT INT TERM

##########################################################
# 3. Gather images older than 6 months ( ignore excludes )
##########################################################

echo "Scanning for images older than $SIX_MONTHS ..."
if [ "$USE_UNTIL_FILTER" = true ]; then
    $CLI images --filter "until=$SIX_MONTHS" \
                --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.CreatedAt}}' \
                > "${IMAGES}.all"
else
    echo "Skipping age filter for images due to unsupported 'until' filter"
    $CLI images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.CreatedAt}}' \
                > "${IMAGES}.all"
fi

while read repo_tag image_id created; do
    if prefix_match "$repo_tag"; then
        echo "Keeping image $repo_tag (matches exclude list)"
    else
        printf '%s %s %s\n' "$repo_tag" "$image_id" "$created" >> "$IMAGES"
    fi
done < "${IMAGES}.all"

if [ ! -s "$IMAGES" ]; then
    echo "No removable images found."
else
    COUNT=$(wc -l < "$IMAGES")
    echo
    echo "$COUNT image(s) marked for removal:"
    awk '{printf "  %s (ID %s)\n", $1, $2}' "$IMAGES"
fi
echo

##########################################################
# 4. Find containers based on images identified in 3.
##########################################################
if [ -s "$IMAGES" ]; then
    while read _repo_tag image_id _; do
        $CLI ps -a --filter "ancestor=$image_id" \
               --format '{{.ID}} {{.Names}} {{.Image}}' >> "$CONTAINERS" || true
    done < "$IMAGES"

    if [ -s "$CONTAINERS" ]; then
        COUNT=$(wc -l < "$CONTAINERS")
        echo "$COUNT dependent container(s):"
        awk '{printf "  %s (%s)\n", $1, $2}' "$CONTAINERS"
    else
        echo "No containers depend on these images."
    fi
    echo
fi

##########################################################
# 5. Perform Deletes ( Delete Mode Only )
##########################################################
if [ "$ACTION" = "delete" ]; then
    if [ -s "$CONTAINERS" ]; then
        echo "Removing containers ..."
        awk '{print $1}' "$CONTAINERS" | xargs -r $CLI rm -f
    fi
    if [ -s "$IMAGES" ]; then
        echo "Removing images ..."
        awk '{print $2}' "$IMAGES" | xargs -r $CLI rmi -f
    fi
    echo
fi

##########################################################
# 6. Prune exited containers older than 7 days (with exclusions)
##########################################################
echo "Pruning exited containers older than $ONE_WEEK (168h) ..."

NOW=$(date +%s)
THRESHOLD=$(( 60 * 60 * 24 * 7 ))   # 7 days in seconds

# Fetch: ID  CreatedAt  Image
$CLI ps -a --filter "status=exited" \
         --format '{{.ID}} {{.CreatedAt}} {{.Image}}' > "$OLD_CONTAINERS"

if [ ! -s "$OLD_CONTAINERS" ]; then
    echo "No exited containers found."
else
    while IFS=' ' read -r cid cdate ctime offset image; do
        created_epoch=$(date -d "$cdate $ctime $offset" +%s 2>/dev/null || echo 0)
        age=$(( NOW - created_epoch ))

        # Older than 7 days?
        if [ "$age" -ge "$THRESHOLD" ]; then
            if prefix_match "$image"; then
                echo "Skipping $cid  (image $image matches exclusion list)"
            else
                run rm -f "$cid"
            fi
        fi
    done < "$OLD_CONTAINERS"
fi
echo

##########################################################
# 7. Remove images where TAG is <none>
##########################################################
echo "Scanning for images where TAG is <none> and older than 5 days ..."

if [ "${USE_UNTIL_FILTER:-false}" = true ]; then
    _imglist=$($CLI images --filter "until=$FIVE_DAYS" --format '{{.Repository}} {{.Tag}} {{.ID}}')
else
    echo "Skipping age filter for <none>-tag images (unsupported 'until' filter)."
    _imglist=$($CLI images --format '{{.Repository}} {{.Tag}} {{.ID}}')
fi

none_tag_images=$(printf '%s\n' "$_imglist" | awk '$2=="<none>" {print $3}' | sort -u)

if [ -n "$none_tag_images" ]; then
    count=$(printf '%s\n' "$none_tag_images" | wc -l | tr -d ' ')
    echo "Found $count image(s) with <none> tag older than 5 days."

    if [ "$ACTION" = "delete" ]; then
        echo "Removing images with <none> tag..."
        # shellcheck disable=SC2086
        run rmi -f $none_tag_images
    else
        echo "CHECK mode: would remove images with <none> tag."
        for iid in $none_tag_images; do
            printf 'Would run: %s rmi -f %s %s\n' "$CLI" "$iid" "$EXTRA_ARGS"
        done
    fi
else
    echo "No <none> tag images older than 5 days found."
fi
echo

##########################################################
# 8. Other prune operations (skip image prune if exclusions present)
##########################################################
echo "Pruning builder cache older than $TWO_WEEKS ..."
if [ "$USE_UNTIL_FILTER" = true ]; then
    run builder prune --filter "until=$TWO_WEEKS" -af
else
    echo "Skipping builder cache age filter (unsupported)"
    run builder prune -af
fi
echo

if [ "$EXCLUDE_PREFIXES" = "$DEFAULT_EXCLUDES" ]; then
    echo "Pruning unused images ..."
    run image prune -af
    echo
else
    echo "Skipping global image prune (custom exclusions active)."
    echo
fi

echo "Pruning unused volumes ..."
run volume prune -f
echo

echo "Pruning unused networks ..."
run network prune -f
echo

###########################################################################
# 9. Always remove AdoptOpenJDK Test Container images (exclude *build*)
###########################################################################
echo "Scanning for AdoptOpenJDK Test Container images (excluding build)..."

ADO_IMAGES=$(
    $CLI images --format '{{.Repository}} {{.ID}}' \
        | grep -i adoptopenjdk \
        | grep -vi build \
        | awk '{print $2}' \
        | sort -u
)

if [ -z "$ADO_IMAGES" ]; then
    echo "No AdoptOpenJDK images (non-build) found for forced removal."
else
    COUNT=$(printf '%s\n' "$ADO_IMAGES" | wc -l | tr -d ' ')
    echo "Found $COUNT AdoptOpenJDK image(s) for forced removal:"
    printf '%s\n' "$ADO_IMAGES" | sed 's/^/  /'

    if [ "$ACTION" = "delete" ]; then
        echo "Removing AdoptOpenJDK images..."
        for iid in $ADO_IMAGES; do
            run rmi -f "$iid"
        done
    else
        echo "CHECK mode: would remove these AdoptOpenJDK images."
        for iid in $ADO_IMAGES; do
            printf 'Would run: %s rmi -f %s %s\n' "$CLI" "$iid" "$EXTRA_ARGS"
        done
    fi
fi

echo

##########################################################
# 10. Summary
##########################################################
echo "Housekeeping finished in $ACTION mode."
