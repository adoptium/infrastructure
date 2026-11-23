#!/bin/bash
# Build a DockerStatic Dockerfile and run a runtime smoke test against the resulting image.
#
# Works with docker or podman, both locally and in GitHub Actions. The engine
# is taken from $CONTAINER_ENGINE, otherwise docker is used if present, else podman.
#
# Usage:   build_and_test_dockerfile.sh [--build-only] [--rm-image] <Dockerfile.name | name>
# Example: build_and_test_dockerfile.sh Dockerfile.u2404
#          build_and_test_dockerfile.sh u2404
#
# Exit code is non-zero if the build or any smoke test check fails.

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-$SCRIPT_DIR/../Dockerfiles}"
JAVA_HOME_IN_IMAGE="/usr/lib/jvm/jdk25"
READY_TIMEOUT="${READY_TIMEOUT:-60}"

build_only=false
rm_image=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --build-only) build_only=true; shift ;;
        --rm-image) rm_image=true; shift ;;
        -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) break ;;
    esac
done

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 [--build-only] [--rm-image] <Dockerfile.name | name>" >&2
    exit 2
fi

name="${1##*/}"
name="${name#Dockerfile.}"
dockerfile="$DOCKERFILE_DIR/Dockerfile.$name"
if [[ ! -f "$dockerfile" ]]; then
    echo "Dockerfile not found: $dockerfile" >&2
    exit 2
fi

if [[ -n "${CONTAINER_ENGINE:-}" ]]; then
    engine="$CONTAINER_ENGINE"
elif command -v docker >/dev/null 2>&1; then
    engine=docker
elif command -v podman >/dev/null 2>&1; then
    engine=podman
else
    echo "Neither docker nor podman found" >&2
    exit 2
fi

image="dockerstatic-check/$name:ci"
container="dockerstatic-check-$name-$$"
failures=0

cleanup() {
    "$engine" rm -f "$container" >/dev/null 2>&1
    if $rm_image; then
        "$engine" rmi -f "$image" >/dev/null 2>&1
    fi
}
trap cleanup EXIT

check() {
    # check <description> <command...> : run command inside the container
    local description="$1"
    shift
    if "$engine" exec "$container" "$@" >/dev/null 2>&1; then
        echo "  PASS: $description"
    else
        echo "  FAIL: $description"
        failures=$((failures + 1))
    fi
}

echo "::group::Build $name using $engine"
echo "Building $dockerfile"
# The Dockerfiles have no COPY/ADD, so the Dockerfiles directory is a sufficient build context.
if ! "$engine" build -f "$dockerfile" -t "$image" "$DOCKERFILE_DIR"; then
    echo "::endgroup::"
    echo "::error title=Build failed::Dockerfile.$name failed to build"
    exit 1
fi
echo "::endgroup::"
echo "Build of Dockerfile.$name succeeded"

if $build_only; then
    exit 0
fi

echo "::group::Smoke test $name"

# The JDK is downloaded for the architecture named in the Dockerfile (x64 or aarch64). The
# Dockerfiles for aarch64 can be built on an x64 host (e.g. locally) but the JDK cannot be run there.
case "$(uname -m)" in
    x86_64) host_arch=x64 ;;
    aarch64|arm64) host_arch=aarch64 ;;
    *) host_arch="$(uname -m)" ;;
esac
image_arch="$(grep -oE 'linux/(x64|aarch64)/' "$dockerfile" | head -n 1 | cut -d/ -f2)"
can_run_java=true
if [[ -n "$image_arch" && "$image_arch" != "$host_arch" ]]; then
    can_run_java=false
    echo "NOTE: Dockerfile targets $image_arch but host is $host_arch, skipping java/ant execution checks"
fi

if ! "$engine" run --detach --name "$container" "$image" >/dev/null; then
    echo "::endgroup::"
    echo "::error title=Smoke test failed::Could not start a container from $image"
    exit 1
fi

# Wait for sshd (the container CMD) to accept connections on port 22.
ready=false
for ((i = 0; i < READY_TIMEOUT; i++)); do
    if "$engine" exec "$container" bash -c 'exec 3<>/dev/tcp/127.0.0.1/22' >/dev/null 2>&1; then
        ready=true
        break
    fi
    sleep 1
done
if $ready; then
    echo "  PASS: sshd is listening on port 22"
else
    echo "  FAIL: sshd is not listening on port 22 after ${READY_TIMEOUT}s"
    failures=$((failures + 1))
    echo "--- container logs ---"
    "$engine" logs "$container" 2>&1 | tail -n 30
fi

check "sshd configuration is valid" sshd -t
check "SSH password authentication is disabled" bash -c "sshd -T | grep -qx 'passwordauthentication no'"
check "SSH keyboard-interactive authentication is disabled" bash -c "sshd -T | grep -qx 'kbdinteractiveauthentication no'"
# Jenkins nodes need ecdsa host keys; some images (e.g. ubi10) intentionally have no RSA key.
check "SSH ecdsa host key exists" test -s /etc/ssh/ssh_host_ecdsa_key
check "jenkins user exists with authorized_keys" bash -c 'id jenkins && test -s /home/jenkins/.ssh/authorized_keys'
check "nagios user exists with authorized_keys" bash -c 'id nagios && test -s /home/nagios/.ssh/authorized_keys'
check "JDK present at $JAVA_HOME_IN_IMAGE" test -x "$JAVA_HOME_IN_IMAGE/bin/java"
check "ant is installed" test -x /usr/bin/ant
check "git is installed" git --version

if $can_run_java; then
    check "java runs" "$JAVA_HOME_IN_IMAGE/bin/java" -version
    check "ant runs" env JAVA_HOME="$JAVA_HOME_IN_IMAGE" ant -version
fi
echo "::endgroup::"

if [[ $failures -ne 0 ]]; then
    echo "::error title=Smoke test failed::Dockerfile.$name had $failures failing smoke test check(s)"
    exit 1
fi
echo "Dockerfile.$name: build and smoke test passed"
