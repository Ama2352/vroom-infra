#!/bin/bash
# install-kargo-cli.sh
# Run this inside the k3s-server VM to install the Kargo CLI
# Version must match kargo-chart.yaml targetRevision

KARGO_VERSION="v1.10.3"
BINARY_NAME="kargo-linux-amd64"

echo "Checking for existing Kargo installation..."
if command -v kargo &> /dev/null; then
    INSTALLED=$(kargo version 2>/dev/null | grep -i "client" | awk '{print $NF}')
    if [ "$INSTALLED" = "$KARGO_VERSION" ]; then
        echo "Kargo CLI ${KARGO_VERSION} is already installed."
        kargo version
        exit 0
    fi
    echo "Upgrading Kargo CLI from $INSTALLED to ${KARGO_VERSION}..."
fi

echo "Downloading Kargo CLI ${KARGO_VERSION}..."
curl -LO "https://github.com/akuity/kargo/releases/download/${KARGO_VERSION}/${BINARY_NAME}"

echo "Installing Kargo CLI..."
chmod +x "${BINARY_NAME}"
sudo mv "${BINARY_NAME}" /usr/local/bin/kargo

echo "Verifying installation..."
if command -v kargo &> /dev/null; then
    echo "SUCCESS: Kargo CLI installed!"
    kargo version
else
    echo "ERROR: Installation failed."
    exit 1
fi
