#!/bin/bash
set -ouex pipefail

echo "Installing official Nostr VPN binary..."

# Get the download URL for the latest linux musl release
LATEST_URL=$(curl -s https://api.github.com/repos/mmalmi/nostr-vpn/releases/latest | grep "browser_download_url.*nvpn.*x86_64-unknown-linux-musl.tar.gz" | cut -d '"' -f 4 | head -n 1)

if [ -z "$LATEST_URL" ]; then
    echo "Failed to find Nostr VPN release URL!"
    exit 1
fi

echo "Downloading from $LATEST_URL..."
curl -sL "$LATEST_URL" | tar -xz -C /tmp

# Move the binary into the image
mv /tmp/nvpn/nvpn /usr/bin/nvpn
chmod +x /usr/bin/nvpn

# Clean up
rm -rf /tmp/nvpn

echo "Nostr VPN installed successfully."
