"""Read only the new, powered-off VM's public SSH key; never mount it writable."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(r"C:\VMs\Hermes-Crypto")
VMX = ROOT / "vm" / "Hermes-Crypto.vmx"
VMRUN = r"C:\Program Files\VMware\VMware Workstation\vmrun.exe"
running = subprocess.check_output([VMRUN, "list"], text=True)
if str(VMX).casefold() in running.casefold():
    raise SystemExit("Refusing to inspect a running guest disk")

sys.path.insert(0, str(ROOT / "artifacts" / "disk-read-tools"))
from dissect.hypervisor.disk.vmdk import VMDK
from dissect.volume.disk import Disk
from dissect.extfs.extfs import ExtFS

found = []
with (ROOT / "vm" / "Hermes-Crypto.vmdk").open("rb") as raw:
    disk = VMDK(raw)
    layout = Disk(disk)
    for partition in layout.partitions:
        try:
            fs = ExtFS(partition.open())
        except Exception:
            continue  # EFI partition is not ext4.
        try:
            # Read this exact public file only, not private keys or account data.
            public_key = fs.get("/etc/ssh/ssh_host_ed25519_key.pub").open().read().decode("ascii").strip()
        except FileNotFoundError:
            continue
        fields = public_key.split()
        if len(fields) < 2 or fields[0] != "ssh-ed25519":
            raise SystemExit("Unexpected guest public-key format")
        found.append(" ".join(fields[:2]))
if len(found) != 1:
    raise SystemExit(f"Expected one root filesystem public key, found {len(found)}")
output = ROOT / "artifacts" / "guest-ssh-host-public-key-verified.txt"
output.write_text(found[0] + "\n", encoding="ascii")
print("Read the installed guest's public SSH key from its powered-off VMDK in read-only mode.")
