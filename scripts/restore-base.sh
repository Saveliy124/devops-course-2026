#!/usr/bin/env bash
# Run on 01-clean-install as student; existing SSH connection stays open.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! id devops >/dev/null 2>&1; then
  sudo adduser devops
fi
sudo usermod -aG sudo devops
sudo install -d -m 700 -o devops -g devops /home/devops/.ssh
# Public key is supplied as first argument; no private key is transferred.
sudo install -m 600 -o devops -g devops "${1:?Path to devops_vm.pub required}" /home/devops/.ssh/authorized_keys
sudo test -e /etc/ssh/sshd_config.backup || sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo find /etc/ssh/sshd_config.d -type f -name '*.conf' ! -name 99-hardening.conf -exec sed -i 's/^\([[:space:]]*PasswordAuthentication[[:space:]]\+yes\)/# disabled for lab: \1/' {} +
sudo install -m 644 "$ROOT_DIR/config/99-hardening.conf" /etc/ssh/sshd_config.d/99-hardening.conf
sudo sshd -t
sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|maxauthtries|allowusers)'
sudo systemctl disable --now ssh.socket
sudo systemctl enable ssh.service
sudo systemctl restart ssh.service
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 2222/tcp comment 'SSH rate-limited'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable
sudo ufw logging medium
sudo hostnamectl set-hostname devops-vm
sudo sed -i 's/^127.0.1.1.*/127.0.1.1 devops-vm.devops.local devops-vm/' /etc/hosts
hostname -f
sudo ss -tlnp | grep sshd
sudo ufw status verbose
echo 'Update NAT guest port 22 -> 2222 on host; test a new ssh devops connection before closing this one.'
