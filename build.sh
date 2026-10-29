#!/bin/bash
set -eo pipefail

# Ensure the script always runs from its own directory, no matter where it is called from
cd "$(dirname "$0")"

# The Tower-PC in Augsburg does the actual build: this laptop has ~7GiB RAM and a
# COSMIC+BlueBuild build OOMs on it. Keep the target in one place.
TOWER_NAME="tomahawk-fedora"
TOWER_HOST="tomahawk-fedora.taila950fb.ts.net"
# Never block on a password prompt or a dead host; fail fast instead.
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes -o ServerAliveInterval=15"

preflight_tower() {
    # 1. Tailnet peer state - local, instant, and it knows the offline duration.
    if command -v tailscale >/dev/null 2>&1; then
        local peer_line
        peer_line=$(tailscale status 2>/dev/null | grep -E "[[:space:]]${TOWER_NAME}[[:space:]]" | head -n1 || true)
        if [ -n "$peer_line" ]; then
            case "$peer_line" in
                *offline*|*stopped*)
                    echo "❌ Tower-PC is not online on the tailnet."
                    echo "   tailscale status: $(printf '%s' "$peer_line" | sed 's/[[:space:]]\\+/ /g')"
                    # Local builds DO work on this machine (build.log, 2026-09-20), so
                    # do not tell the user he is stuck - the caller falls back to local.
                    echo "   Tower is in Augsburg, ~500km away; if you need it, someone"
                    echo "   there must power it on, or set up a smart plug + Wake-on-LAN."
                    return 1 ;;
            esac
        else
            echo "⚠  ${TOWER_NAME} is absent from 'tailscale status' - it may be logged out."
        fi
    fi

    # 2. TCP probe of sshd. An offline Tailscale peer blackholes SYNs, so cap it hard.
    if timeout 12 bash -c "cat < /dev/null > /dev/tcp/${TOWER_HOST}/22" 2>/dev/null; then
        return 0
    fi
    echo "❌ Cannot reach ${TOWER_HOST}:22 (probe timed out after 12s)."
    echo "   Same cause: the tower is off and remote from Berlin."
    return 1
}

# Calculate a secure hash of the current project state (ignoring the auto-generated timestamp file)
CURRENT_HASH=$(find recipe.yml scripts files -type f ! -path "*/files/etc/image-description" -exec sha256sum {} + 2>/dev/null | sort | sha256sum | awk '{print $1}')

if [ -f .last_build_hash ] && [ "$CURRENT_HASH" = "$(cat .last_build_hash)" ]; then
    echo "Nothing to do (no changes detected)"
    exit 0
fi

if [ "$1" != "--local" ]; then
    # The remote tower in Augsburg is preferred when it is reachable: it is the
    # machine this pipeline was built around. It is optional though - this laptop
    # HAS built my-custom-os locally (see build.log, 2026-09-20), so a dead tower
    # must not block the pipeline. Offer local instead of dead-ending.
    # Keep the caller's args: $1 may be a commit message that must survive the
    # fallback. Prepending --local and shifting again would drop its first word.
    REMOTE_ARGS=("$@")
    if ! preflight_tower; then
        echo ""
        echo "💡 Falling back to a local build on this machine."
        echo "   (Previously successful here on 2026-09-20; slow, but no remote needed.)"
        set -- --local "${REMOTE_ARGS[@]}"
    else
        # Fail fast and legibly instead of hanging on a 2-minute ssh/rsync connect timeout.
        echo "🚀 Syncing changes to Tower-PC over Tailscale..."
        rsync -avz -e "ssh ${SSH_OPTS}" --exclude='.git' ./ "michael@${TOWER_HOST}:~/Coding/my-custom-os/"
        echo ""
        echo "⚙️ Triggering remote OS build on Tower-PC..."
        # If the remote build succeeds, we save the hash locally so we don't sync again until you make a change
        if ssh ${SSH_OPTS} "michael@${TOWER_HOST}" "cd ~/Coding/my-custom-os && ./build.sh --local \"$*\""; then
            echo "$CURRENT_HASH" > .last_build_hash
            exit 0
        else
            exit 1
        fi
    fi
fi

# We are building locally. Shift off the --local argument so $1 becomes the commit message (if provided)
shift

mkdir -p files/etc
BUILD_DATE=$(date "+%Y-%m-%d %H:%M:%S")

if [ -n "$1" ]; then
    COMMIT_MSG="$1"
else
    COMMIT_MSG=$(python3 scripts/auto-describe.py)
fi

FULL_DESC="Build: $BUILD_DATE | $COMMIT_MSG"
echo "$FULL_DESC" > files/etc/image-description

echo "Cleaning up previous latest tag to prevent BlueBuild manifest collisions..."
podman rmi localhost/my-custom-os:latest 2>/dev/null || true

echo "Starting BlueBuild..."
./bluebuild build ./recipe.yml 2>&1 | tee build.log

echo "Applying dynamic update description label..."
echo "FROM localhost/my-custom-os:latest" > Containerfile.label
echo "LABEL org.opencontainers.image.description=\"$FULL_DESC\"" >> Containerfile.label
# Apply dynamic label natively; Podman will silently reassign the existing 'latest' tag
podman build -t localhost/my-custom-os:latest -f Containerfile.label .
rm Containerfile.label

# BlueBuild always generates tags based on today's date and the OS version
DATE_TAG=$(date +%Y%m%d)
VERSION_TAG="44"

echo "Cleaning up redundant BlueBuild tags..."
# We use || true so the script doesn't crash if the tags were already deleted
podman manifest rm localhost/my-custom-os:${DATE_TAG} localhost/my-custom-os:${VERSION_TAG} localhost/my-custom-os:${DATE_TAG}-${VERSION_TAG} 2>/dev/null || true

echo "Pushing clean image to local registry..."
podman tag localhost/my-custom-os:latest localhost:5000/my-custom-os:latest
podman push localhost:5000/my-custom-os:latest --tls-verify=false

echo -e "\n📝 Update Description: $FULL_DESC"
duration=$SECONDS
echo "⏱️ Build completed in $(($duration / 60))m $(($duration % 60))s"
echo "✅ Build, cleanup, and push complete! Your laptop is ready to upgrade."

# Save the hash so subsequent identical runs exit instantly
echo "$CURRENT_HASH" > .last_build_hash
