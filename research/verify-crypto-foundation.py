"""Check the new guest foundation without installing trading software."""
import importlib.util
import json
import os
import shutil
import socket
import subprocess
from pathlib import Path

def command(*args):
    return subprocess.check_output(args, text=True).strip()

assert socket.gethostname() == "hermes-crypto"
assert command("systemd-detect-virt") == "vmware"
assert os.getuid() == 1000
assert Path("/etc/crypto-foundation-complete").is_file()
assert not shutil.which("docker")
assert not shutil.which("freqtrade")
assert not shutil.which("hermes")
assert importlib.util.find_spec("freqtrade") is None
assert "Status: active" in command("sudo", "-n", "ufw", "status")

def private_drop_count():
    output = command("sudo", "-n", "iptables", "-nvx", "-L", "ufw-user-output")
    return sum(int(row[0]) for line in output.splitlines()
               if len(row := line.split()) >= 9
               and row[2] == "DROP" and row[8] == "192.168.0.0/16")

before = private_drop_count()
with socket.socket() as probe:
    probe.settimeout(2)
    try:
        probe.connect(("192.168.50.1", 445))
        raise AssertionError("Guest reached host SMB port")
    except (TimeoutError, OSError):
        pass
after = private_drop_count()
assert after > before, "No firewall DROP counter increase observed"

updates = command("apt", "list", "--upgradable")
assert not any("[upgradable from:" in line for line in updates.splitlines())
assert command("timedatectl", "show", "-p", "NTPSynchronized", "--value") == "yes"
assert command("systemctl", "is-active", "ssh") == "active"
assert command("systemctl", "is-active", "open-vm-tools") == "active"
assert command("systemctl", "--failed", "--no-legend", "--no-pager") == ""
ssh_config = command("sudo", "-n", "sshd", "-T")
for setting in ("permitrootlogin no", "passwordauthentication no",
                "kbdinteractiveauthentication no", "allowagentforwarding no",
                "allowtcpforwarding local", "allowusers cryptoops"):
    assert setting in ssh_config.splitlines(), setting

print(json.dumps({
    "hostname": socket.gethostname(),
    "os": command("lsb_release", "-ds"),
    "kernel": command("uname", "-r"),
    "vcpu_count": os.cpu_count(),
    "memory_kib": int(Path("/proc/meminfo").read_text().splitlines()[0].split()[1]),
    "root_disk": command("df", "-h", "/"),
    "ssh_key_only": True,
    "private_network_block_verified": True,
    "private_drop_counter_delta": after - before,
    "time_synchronised": True,
    "pending_upgrades": False,
    "docker_freqtrade_hermes_absent": True,
    "failed_services": [],
    "checked_at": command("date", "--iso-8601=seconds"),
}, indent=2))
