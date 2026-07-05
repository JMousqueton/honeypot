#!/usr/bin/env bash
#
# build-cowrie.sh - Build the Cohesity One / T-Pot cowrie container and push it to GHCR.
#
# Produces:  ghcr.io/jmousqueton/cowrie:24.04.1  (multi-arch: linux/amd64, linux/arm64)
#
# The cowrie image generates its persona configs at build time (generate_cowrie_fs.py),
# including the [output_virustotal] section wired to the COWRIE_VT_API_KEY env var, so
# rebuild this after changing anything under docker/cowrie/dist/.
#
# Usage:
#   ./build-cowrie.sh                 # build + push (multi-arch)
#   ./build-cowrie.sh -n              # build + push with --no-cache
#   ./build-cowrie.sh -l              # local single-arch build, load into docker, NO push
#   ./build-cowrie.sh -h              # help
#
# Auth (for pushing) - either be logged in already, or export:
#   GHCR_USER=<github-username>  GHCR_PAT=<PAT with write:packages>
#

set -euo pipefail

# --- Config -----------------------------------------------------------------
IMAGE="ghcr.io/jmousqueton/cowrie"
VERSION="24.04.1"
CONTEXT="docker/cowrie"
PLATFORMS="linux/amd64,linux/arm64"
BUILDER="mybuilder"

# --- Options ----------------------------------------------------------------
NO_CACHE=""
LOCAL=false

usage() {
    # Print only the leading doc block (comment lines after the shebang,
    # up to the first blank line).
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
    exit "${1:-0}"
}

while getopts ":nlh" opt; do
    case "$opt" in
        n) NO_CACHE="--no-cache" ;;
        l) LOCAL=true ;;
        h) usage 0 ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage 1 ;;
    esac
done

# --- Resolve script dir so it can be run from anywhere ----------------------
cd "$(dirname "$0")"

TAG="${IMAGE}:${VERSION}"

echo "###########################################"
echo "# Building cowrie image"
echo "#   image:     ${TAG}"
echo "#   context:   ${CONTEXT}"
if $LOCAL; then
    echo "#   mode:      local (single-arch, load, no push)"
else
    echo "#   platforms: ${PLATFORMS} (push to GHCR)"
fi
echo "###########################################"
echo

if [ ! -f "${CONTEXT}/Dockerfile" ]; then
    echo "ERROR: ${CONTEXT}/Dockerfile not found - run this from the project root." >&2
    exit 1
fi

# --- Local single-arch path (quick test, no registry) -----------------------
if $LOCAL; then
    docker build ${NO_CACHE} -t "${TAG}" "${CONTEXT}"
    echo
    echo "Done. Loaded locally as ${TAG} (not pushed)."
    echo "Test it:  docker run --rm -e COWRIE_VT_API_KEY=<key> -p 22:22 -p 23:23 ${TAG}"
    exit 0
fi

# --- Login to GHCR (only if creds provided; otherwise assume existing login) -
if [ -n "${GHCR_PAT:-}" ] && [ -n "${GHCR_USER:-}" ]; then
    echo -n "Logging in to ghcr.io as ${GHCR_USER}... "
    echo "${GHCR_PAT}" | docker login ghcr.io -u "${GHCR_USER}" --password-stdin >/dev/null
    echo "OK"
else
    echo "No GHCR_USER/GHCR_PAT set - assuming you are already logged in to ghcr.io."
    echo "  (If push fails: echo \$CR_PAT | docker login ghcr.io -u <user> --password-stdin)"
fi
echo

# --- Ensure a buildx builder + QEMU for cross-arch builds -------------------
if ! docker buildx inspect "${BUILDER}" >/dev/null 2>&1; then
    echo -n "Creating buildx builder '${BUILDER}'... "
    docker buildx create --name "${BUILDER}" --driver docker-container --use >/dev/null
    echo "OK"
else
    docker buildx use "${BUILDER}"
fi
docker buildx inspect "${BUILDER}" --bootstrap >/dev/null

echo -n "Ensuring QEMU (binfmt) for cross-platform builds... "
docker run --rm --privileged tonistiigi/binfmt --install all >/dev/null 2>&1 && echo "OK" || echo "skipped"
echo

# --- Build + push -----------------------------------------------------------
docker buildx build \
    --platform "${PLATFORMS}" \
    --tag "${TAG}" \
    ${NO_CACHE} \
    --push \
    "${CONTEXT}"

echo
echo "###########################################"
echo "# Done. Pushed ${TAG}"
echo "###########################################"
