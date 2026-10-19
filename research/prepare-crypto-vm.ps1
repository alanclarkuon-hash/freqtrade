$ErrorActionPreference = 'Stop'
# Fresh crypto VM only. Creates new artifacts; never touches existing VMs, WSL or Docker Desktop.
$vmRoot = 'C:\VMs\Hermes-Crypto'
$vmDir = Join-Path $vmRoot 'vm'
$privateDir = Join-Path $vmRoot 'private'
$seedDir = Join-Path $vmRoot 'seed'
$artifactDir = Join-Path $vmRoot 'artifacts'
$pythonExe = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$vmwareDir = 'C:\Program Files\VMware\VMware Workstation'
$sourceIso = 'C:\VMs\Hermes-Validation\artifacts\ubuntu-24.04.5-live-server-amd64.iso'
# Official HTTPS metadata checked 2026-10-19:
# https://releases.ubuntu.com/24.04/SHA256SUMS
if (Test-Path -LiteralPath $vmRoot) { throw "Refusing existing crypto VM destination: $vmRoot" }
if ((Get-Item -LiteralPath 'C:\VMs').Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Refusing redirected VM parent directory'
}
if ((Get-FileHash -LiteralPath $sourceIso -Algorithm SHA256).Hash -ne '97F3D7FFB032C3EB3B23D2C8BE9CC76E60C2C1F2C0146BA5BA9FE01CAFAE0FD8') {
    throw 'Source Ubuntu ISO digest mismatch'
}
New-Item -ItemType Directory -Path $vmRoot | Out-Null
$cryptoOperatorSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $vmRoot /inheritance:r /grant:r "*${cryptoOperatorSid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'New VM directory ACL setup failed' }
New-Item -ItemType Directory -Path $artifactDir | Out-Null
Copy-Item -LiteralPath $sourceIso -Destination (Join-Path $artifactDir 'ubuntu-24.04.5-live-server-amd64.iso')
foreach ($path in @($vmDir, $privateDir, $seedDir)) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to overwrite existing provisioning state: $path" }
}
$iso = Join-Path $artifactDir 'ubuntu-24.04.5-live-server-amd64.iso'
if ((Get-FileHash -LiteralPath $iso -Algorithm SHA256).Hash -ne '97F3D7FFB032C3EB3B23D2C8BE9CC76E60C2C1F2C0146BA5BA9FE01CAFAE0FD8') {
    throw 'Ubuntu installer digest mismatch'
}
foreach ($path in @($vmDir, $privateDir, $seedDir)) { New-Item -ItemType Directory -Path $path | Out-Null }
$userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $privateDir /inheritance:r /grant:r "*${userSid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Private directory ACL setup failed' }
$keyScript = @'
from pathlib import Path
import secrets, subprocess
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization
root = Path(r'C:\VMs\Hermes-Crypto')
key = ed25519.Ed25519PrivateKey.generate()
(root/'private'/'operator_ed25519').write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.OpenSSH, serialization.NoEncryption()))
public = key.public_key().public_bytes(serialization.Encoding.OpenSSH, serialization.PublicFormat.OpenSSH).decode() + ' hermes-crypto-operator'
(root/'private'/'operator_ed25519.pub').write_text(public+'\n', encoding='utf-8')
random_password = secrets.token_urlsafe(48)
hashed = subprocess.run([r'C:\Program Files\Git\usr\bin\openssl.exe','passwd','-6','-stdin'], input=(random_password+'\n').encode(), stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout.decode().strip()
if not hashed.startswith('$6$'): raise RuntimeError('Unexpected password hash')
user_data = '''#cloud-config
autoinstall:
  version: 1
  refresh-installer:
    update: false
  locale: en_GB.UTF-8
  keyboard:
    layout: gb
  timezone: Europe/London
  identity:
    hostname: hermes-crypto
    username: cryptoops
    realname: Hermes Crypto Operator
    password: "HASH_PLACEHOLDER"
  storage:
    layout:
      name: direct
  ssh:
    install-server: true
    allow-pw: false
    authorized-keys:
      - "KEY_PLACEHOLDER"
  packages:
    - open-vm-tools
    - ca-certificates
    - curl
    - ufw
  updates: security
  user-data:
    disable_root: true
    ssh_pwauth: false
  late-commands:
    - curtin in-target -- ssh-keygen -A
    - [sh, -c, "printf 'cryptoops ALL=(ALL) NOPASSWD:ALL\\n' > /target/etc/sudoers.d/90-hermes-operator; chmod 440 /target/etc/sudoers.d/90-hermes-operator"]
    - [sh, -c, "{ printf '\\nHERMES_HOSTKEY '; cat /target/etc/ssh/ssh_host_ed25519_key.pub; printf '\\nHERMES_INSTALL_COMPLETE\\n'; } > /dev/ttyS0"]
  shutdown: poweroff
'''.replace('HASH_PLACEHOLDER', hashed).replace('KEY_PLACEHOLDER', public)
(root/'seed'/'user-data').write_text(user_data, encoding='utf-8')
(root/'seed'/'meta-data').write_text('instance-id: hermes-crypto-foundation-01\nlocal-hostname: hermes-crypto\n', encoding='utf-8')
print('Created guest-only SSH key and seed data; private key and password omitted from output.')
'@
$keyScript | & $pythonExe -
if ($LASTEXITCODE -ne 0) { throw 'Guest seed generation failed' }

# Use the built-in Windows ISO writer, not another installed tool or WSL.
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class HermesIsoStreamWriter {
    public static void Write(object comStream, string path) {
        IStream stream = (IStream)comStream;
        byte[] buffer = new byte[65536];
        IntPtr readPointer = Marshal.AllocHGlobal(sizeof(int));
        try {
            using (FileStream output = new FileStream(path, FileMode.CreateNew, FileAccess.Write)) {
                while (true) {
                    stream.Read(buffer, buffer.Length, readPointer);
                    int read = Marshal.ReadInt32(readPointer);
                    if (read <= 0) break;
                    output.Write(buffer, 0, read);
                }
            }
        } finally { Marshal.FreeHGlobal(readPointer); }
    }
}
'@
$image = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$image.FileSystemsToCreate = 3
$image.VolumeName = 'CIDATA'
$image.Root.AddTree($seedDir, $false)
$result = $image.CreateResultImage()
$seedIso = Join-Path $artifactDir 'hermes-cidata.iso'
[HermesIsoStreamWriter]::Write($result.ImageStream, $seedIso)

& (Join-Path $vmwareDir 'vmware-vdiskmanager.exe') -c -s 120GB -a lsilogic -t 0 (Join-Path $vmDir 'Hermes-Crypto.vmdk')
if ($LASTEXITCODE -ne 0) { throw 'New VM virtual disk creation failed' }
$vmx = @'
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "21"
displayName = "Hermes-Crypto"
guestOS = "ubuntu-64"
firmware = "efi"
memsize = "8192"
numvcpus = "4"
cpuid.coresPerSocket = "4"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "Hermes-Crypto.vmdk"
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.deviceType = "cdrom-image"
sata0:0.fileName = "C:\VMs\Hermes-Crypto\artifacts\ubuntu-24.04.5-live-server-amd64.iso"
sata0:0.startConnected = "TRUE"
sata0:1.present = "TRUE"
sata0:1.deviceType = "cdrom-image"
sata0:1.fileName = "C:\VMs\Hermes-Crypto\artifacts\hermes-cidata.iso"
sata0:1.startConnected = "TRUE"
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "e1000"
ethernet0.addressType = "generated"
ethernet0.startConnected = "TRUE"
usb.present = "FALSE"
usb_xhci.present = "FALSE"
usb.autoConnect.device0 = ""
sound.present = "FALSE"
floppy0.present = "FALSE"
mks.enable3d = "FALSE"
isolation.tools.copy.disable = "TRUE"
isolation.tools.paste.disable = "TRUE"
isolation.tools.dnd.disable = "TRUE"
isolation.tools.hgfs.disable = "TRUE"
sharedFolder.maxNum = "0"
vhv.enable = "FALSE"
serial0.present = "TRUE"
serial0.fileType = "file"
serial0.fileName = "C:\VMs\Hermes-Crypto\artifacts\guest-install-serial.log"
serial0.startConnected = "TRUE"
tools.syncTime = "FALSE"
msg.autoAnswer = "TRUE"
uefi.bootOrder = "cdrom,hdd"
'@
[IO.File]::WriteAllText((Join-Path $vmDir 'Hermes-Crypto.vmx'), $vmx, [Text.UTF8Encoding]::new($false))
Write-Output 'Prepared isolated 4-vCPU / 8-GiB / 120-GB VM and CIDATA media. VM has not been started.'
