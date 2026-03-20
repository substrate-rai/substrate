#!/bin/bash
# Substrate Gentoo Installation Script
# Run from the LiveGUI environment after mounting USB 2
#
# Usage: bash /mnt/usb/substrate-migration/gentoo/install.sh
#
# Prerequisites:
#   - Booted from Gentoo LiveGUI USB
#   - USB 2 mounted at /mnt/usb
#   - Internet connected (WiFi via NetworkManager in KDE live session)
#   - stage3 tarball on USB 2 at /mnt/usb/substrate-migration/
#
# Disk: /dev/nvme0n1 (1.8TB KINGSTON SNV2S2000G)
# Layout: GPT → EFI (512MB) + swap (16GB) + BTRFS (rest)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[*]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[!]${NC} $1"; exit 1; }
ask()   { echo -en "${YELLOW}[?]${NC} $1 [y/N] "; read -r ans; [[ "$ans" =~ ^[Yy] ]]; }

USB="/mnt/usb/substrate-migration"
STAGE3=$(ls "${USB}"/stage3-amd64-desktop-openrc-*.tar.xz 2>/dev/null | head -1)
DISK="/dev/nvme0n1"
MOUNT="/mnt/gentoo"

# --- Preflight Checks ---
info "Substrate Gentoo Installer"
echo "========================================="
echo "Disk:    ${DISK}"
echo "Mount:   ${MOUNT}"
echo "Stage3:  ${STAGE3:-NOT FOUND}"
echo "USB:     ${USB}"
echo "========================================="

[ -d "$USB" ] || error "USB not mounted at ${USB}. Mount it first: mount /dev/sdX1 /mnt/usb"
[ -f "$STAGE3" ] || error "Stage3 tarball not found on USB. Download it first."
[ -b "$DISK" ] || error "Disk ${DISK} not found"

if ! ask "This will ERASE ALL DATA on ${DISK}. Continue?"; then
    echo "Aborted."
    exit 0
fi

# === PHASE 1: Partition ===
info "Partitioning ${DISK} (GPT: EFI + swap + BTRFS)"

wipefs -a "${DISK}"
parted -s "${DISK}" mklabel gpt
parted -s "${DISK}" mkpart "EFI"  fat32  1MiB    513MiB
parted -s "${DISK}" set 1 esp on
parted -s "${DISK}" mkpart "swap" linux-swap 513MiB  16897MiB
parted -s "${DISK}" mkpart "root" btrfs  16897MiB 100%

info "Formatting partitions"
mkfs.fat -F32 "${DISK}p1"
mkswap "${DISK}p2"
swapon "${DISK}p2"
mkfs.btrfs -f -L substrate "${DISK}p3"

# === PHASE 2: BTRFS Subvolumes ===
info "Creating BTRFS subvolumes"
mount "${DISK}p3" "${MOUNT}"

btrfs subvolume create "${MOUNT}/@"
btrfs subvolume create "${MOUNT}/@home"
btrfs subvolume create "${MOUNT}/@snapshots"
btrfs subvolume create "${MOUNT}/@var_log"

umount "${MOUNT}"

# Mount with subvolumes
mount -o noatime,compress=zstd,subvol=@ "${DISK}p3" "${MOUNT}"
mkdir -p "${MOUNT}"/{home,efi,.snapshots,var/log}
mount -o noatime,compress=zstd,subvol=@home "${DISK}p3" "${MOUNT}/home"
mount -o noatime,compress=zstd,subvol=@snapshots "${DISK}p3" "${MOUNT}/.snapshots"
mount -o noatime,compress=zstd,subvol=@var_log "${DISK}p3" "${MOUNT}/var/log"
mount "${DISK}p1" "${MOUNT}/efi"

# === PHASE 3: Extract Stage3 ===
info "Extracting stage3 tarball (this takes a few minutes)"
tar xpf "${STAGE3}" --xattrs-include='*.*' --numeric-owner -C "${MOUNT}"

# === PHASE 4: Portage Configuration ===
info "Installing Portage configuration from USB"

# make.conf
cp "${USB}/gentoo/make.conf" "${MOUNT}/etc/portage/make.conf"

# Binary package host
mkdir -p "${MOUNT}/etc/portage/binrepos.conf"
cp "${USB}/gentoo/binrepos.conf/gentoobinhost.conf" "${MOUNT}/etc/portage/binrepos.conf/"

# Package USE, keywords, masks
for dir in package.use package.accept_keywords package.mask; do
    mkdir -p "${MOUNT}/etc/portage/${dir}"
    if [ -d "${USB}/gentoo/${dir}" ]; then
        cp "${USB}/gentoo/${dir}"/* "${MOUNT}/etc/portage/${dir}/"
    fi
done

# Package set
mkdir -p "${MOUNT}/etc/portage/sets"
cp "${USB}/gentoo/sets/substrate" "${MOUNT}/etc/portage/sets/"

# Portage bashrc (snapper hooks)
cp "${USB}/gentoo/portage-bashrc" "${MOUNT}/etc/portage/bashrc"

# === PHASE 5: DNS + Chroot Prep ===
info "Preparing chroot environment"
cp --dereference /etc/resolv.conf "${MOUNT}/etc/"

mount --types proc /proc "${MOUNT}/proc"
mount --rbind /sys "${MOUNT}/sys"
mount --make-rslave "${MOUNT}/sys"
mount --rbind /dev "${MOUNT}/dev"
mount --make-rslave "${MOUNT}/dev"
mount --bind /run "${MOUNT}/run"
mount --make-slave "${MOUNT}/run"

# === PHASE 6: Chroot and Install ===
info "Entering chroot — installing base system"

cat > "${MOUNT}/tmp/chroot-install.sh" << 'CHROOT_EOF'
#!/bin/bash
set -euo pipefail

source /etc/profile
export PS1="(chroot) ${PS1}"

# Sync Portage tree
echo "[*] Syncing Portage tree..."
emerge-webrsync
emerge --sync --quiet

# Update @world with binary packages
echo "[*] Updating @world (using binpkgs where available)..."
emerge --update --deep --newuse --getbinpkg @world

# Install kernel
echo "[*] Installing kernel..."
emerge sys-kernel/gentoo-kernel-bin sys-kernel/installkernel sys-kernel/linux-firmware

# GRUB
echo "[*] Installing GRUB..."
emerge sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Gentoo
# Add NVIDIA kernel params
mkdir -p /etc/default
cat >> /etc/default/grub << 'GRUB_CONF'

# Substrate: NVIDIA modesetting + memory preservation for suspend
GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 NVreg_PreserveVideoMemoryAllocations=1"
GRUB_CONF
grub-mkconfig -o /boot/grub/grub.cfg

# Essential services
echo "[*] Installing essential services..."
emerge --getbinpkg \
    sys-apps/openrc \
    sys-auth/elogind \
    sys-apps/dbus \
    net-misc/networkmanager \
    net-misc/openssh \
    app-admin/syslog-ng \
    app-admin/logrotate \
    sys-process/fcron \
    sys-fs/btrfs-progs \
    app-backup/snapper \
    net-analyzer/fail2ban

# NVIDIA drivers + CUDA
echo "[*] Installing NVIDIA drivers..."
emerge --getbinpkg x11-drivers/nvidia-drivers dev-util/nvidia-cuda-toolkit

# Enable critical services
echo "[*] Enabling services..."
rc-update add elogind boot          # MUST be boot, not default!
rc-update add dbus default
rc-update add NetworkManager default
rc-update add sshd default
rc-update add syslog-ng default
rc-update add fcron default
rc-update add fail2ban default
rc-update add nvidia-persistenced default

# Set up eselect
eselect cron set fcron

# fstab
echo "[*] Writing fstab..."
cat > /etc/fstab << 'FSTAB'
# Substrate Gentoo fstab
# <fs>                  <mountpoint>    <type>  <opts>                                      <dump> <pass>
/dev/nvme0n1p1          /efi            vfat    defaults,noatime                            0      2
/dev/nvme0n1p2          none            swap    sw                                          0      0
/dev/nvme0n1p3          /               btrfs   noatime,compress=zstd,subvol=@              0      0
/dev/nvme0n1p3          /home           btrfs   noatime,compress=zstd,subvol=@home          0      0
/dev/nvme0n1p3          /.snapshots     btrfs   noatime,compress=zstd,subvol=@snapshots     0      0
/dev/nvme0n1p3          /var/log        btrfs   noatime,compress=zstd,subvol=@var_log       0      0
FSTAB

# Hostname
echo "substrate" > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost substrate
::1         localhost substrate
HOSTS

# Timezone
echo "America/New_York" > /etc/timezone
emerge --config sys-libs/timezone-data

# Locale
cat > /etc/locale.gen << 'LOCALE'
en_US.UTF-8 UTF-8
en_US ISO-8859-1
LOCALE
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile

# Create operator user
echo "[*] Creating operator user..."
useradd -m -G wheel,video,render,audio,users,plugdev -s /bin/bash operator
echo "[!] Set operator password now:"
passwd operator

# Set root password
echo "[!] Set root password now:"
passwd root

# Allow wheel group to sudo
emerge app-admin/sudo
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

# Install PAM configs
dispatch-conf

echo "[*] Base installation complete!"
echo "[*] After reboot: emerge @substrate for the full stack"
CHROOT_EOF

chmod +x "${MOUNT}/tmp/chroot-install.sh"
chroot "${MOUNT}" /tmp/chroot-install.sh

# === PHASE 7: Cleanup ===
info "Cleaning up"
rm "${MOUNT}/tmp/chroot-install.sh"

umount -l "${MOUNT}/dev"{/shm,/pts,}
umount -l "${MOUNT}"{/proc,/sys,/run}
umount -R "${MOUNT}"

info "Installation complete!"
echo ""
echo "========================================="
echo " Next steps:"
echo "   1. Remove USB 1 (LiveGUI)"
echo "   2. Reboot into Gentoo"
echo "   3. Connect WiFi: nmtui"
echo "   4. Start SSH: rc-service sshd start"
echo "   5. Clone repo: git clone git@github.com:substrate-rai/substrate.git"
echo "   6. Restore secrets from USB 2"
echo "   7. Run: emerge --ask @substrate"
echo "   8. Install OpenRC scripts + fcrontab"
echo "   9. Install Ollama + pull qwen3:8b"
echo "  10. Run verify.sh"
echo "========================================="
