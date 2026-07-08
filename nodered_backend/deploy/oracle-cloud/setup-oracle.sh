#!/bin/bash
# ============================================
# Focus Fitness OS - Oracle Cloud Instance Setup
# Run this ONCE on the Oracle Cloud ARM instance
# Installs: Docker, Docker Compose, creates directories
# ============================================
set -euo pipefail

echo "=========================================="
echo " Focus Fitness OS - Oracle Cloud Setup"
echo "=========================================="

# Check if running on ARM
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" ]]; then
    echo "WARNING: Expected aarch64 (ARM64), got $ARCH"
    echo "Continuing anyway..."
fi

echo "[1/6] Updating system packages..."
sudo dnf update -y

echo "[2/6] Installing Docker..."
if ! command -v docker &> /dev/null; then
    sudo dnf install -y dnf-utils
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    echo "Docker installed successfully"
else
    echo "Docker already installed: $(docker --version)"
fi

echo "[3/6] Creating application directories..."
sudo mkdir -p /opt/ffos/data
sudo mkdir -p /opt/ffos/deploy/certs
sudo mkdir -p /opt/ffos/deploy/logs
sudo chown -R $USER:$USER /opt/ffos
echo "Directories created at /opt/ffos"

echo "[4/6] Configuring firewall..."
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
echo "Firewall configured: ports 80, 443 open"

echo "[5/6] Setting up swap (for memory headroom)..."
if ! swapon --show | grep -q ffos-swap; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    echo "2GB swap created"
else
    echo "Swap already configured"
fi

echo "[6/6] Verifying installation..."
echo "--- System Info ---"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Arch: $ARCH"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $4}') free"
echo "Docker: $(docker --version)"
echo "Compose: $(docker compose version)"

echo ""
echo "=========================================="
echo " Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Copy deploy files to /opt/ffos/deploy/"
echo "2. Create .env file with your secrets"
echo "3. Obtain TLS certificates"
echo "4. Run: docker compose -f /opt/ffos/deploy/docker-compose.yml up -d"
echo ""
