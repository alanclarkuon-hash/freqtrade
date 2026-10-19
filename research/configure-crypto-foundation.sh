#!/usr/bin/env bash
# Foundation only: no trading software, container runtime, or agent installation.
set -euo pipefail
test "$(id -u)" = 0
test "$(hostname)" = hermes-crypto
test "$(systemd-detect-virt)" = vmware
. /etc/os-release
test "$ID" = ubuntu && test "$VERSION_ID" = 24.04
test ! -e /etc/crypto-foundation-complete
test -z "$(command -v docker || true)"
test -z "$(command -v freqtrade || true)"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y full-upgrade
apt-get install -y open-vm-tools openssh-server ca-certificates curl ufw

install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/00-crypto-foundation.conf <<'SSH'
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding local
GatewayPorts no
PermitTunnel no
AllowUsers cryptoops
SSH
sshd -t
systemctl reload ssh

# Guest-only rules. Windows and VMware's shared networking are not changed.
# Preserve NAT DNS and DHCP before denying new connections to private networks.
ufw default deny incoming
ufw default allow outgoing
ufw allow in from 192.168.50.1 to any port 22 proto tcp comment 'Crypto operator SSH'
ufw allow out to 192.168.50.2 port 53 proto udp comment 'VMware NAT DNS'
ufw allow out to 192.168.50.2 port 53 proto tcp comment 'VMware NAT DNS TCP'
ufw allow out to any port 67 proto udp comment 'DHCP renewal'
for network in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10 fc00::/7 fe80::/10; do
    ufw deny out to "$network" comment 'Block private networks from crypto guest'
done
ufw --force enable
systemctl enable ssh open-vm-tools
timedatectl set-timezone Europe/London

test -z "$(command -v docker || true)"
test -z "$(command -v freqtrade || true)"
date --iso-8601=seconds > /etc/crypto-foundation-complete
echo 'CRYPTO_FOUNDATION_CONFIGURED'
ufw status verbose
sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|allowagentforwarding|allowtcpforwarding|gatewayports|x11forwarding|allowusers) '
uname -r
test ! -e /var/run/reboot-required || echo 'GUEST_REBOOT_REQUIRED'
