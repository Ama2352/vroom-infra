#!/bin/bash
# vroom-infra/setup-ngrok.sh
# Installs ngrok and provides instructions for tunneling SonarQube.

set -e

echo "--- Installing ngrok ---"
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt-get update -qq
sudo apt-get install -y ngrok

echo ""
echo "--- Configuration Required ---"
echo "1. Go to https://dashboard.ngrok.com/get-started/your-authtoken"
echo "2. Run: ngrok config add-authtoken <YOUR_TOKEN>"
echo ""
echo "--- How to Start the Tunnel ---"
echo "To expose SonarQube (NodePort 30090), run:"
echo "ngrok http 30090"
echo ""
echo "Once running, copy the 'Forwarding' URL and set it as SONAR_HOST_URL in GitLab CI Variables."
