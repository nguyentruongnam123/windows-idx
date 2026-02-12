#!/usr/bin/env bash
set -e

### CONFIG ###
ISO_URL="https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
ISO_FILE="arch.iso"

DISK_FILE="/var/arch.qcow2"
DISK_SIZE="100G"

RAM="8G"
CORES="8"

VNC_DISPLAY=":0"

FLAG_FILE="installed.flag"
WORKDIR="$HOME/arch-vm"

### CHECK ###
[ -e /dev/kvm ] || { echo "❌ No /dev/kvm"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ No qemu"; exit 1; }

### PREP ###
mkdir -p "$WORKDIR"
cd "$WORKDIR"

chmod 755 "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"

if [ ! -f "$FLAG_FILE" ]; then
  if [ ! -f "$ISO_FILE" ]; then
    echo "📥 Đang tải Arch Linux ISO (900MB)..."
    wget --continue --no-check-certificate --show-progress \
      -O "$ISO_FILE" "$ISO_URL" || \
    wget --continue --no-check-certificate --show-progress \
      -O "$ISO_FILE" "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
    
    echo "✅ Tải xong!"
  fi
fi

############################
# BACKGROUND FILE CREATOR #
############################
(
  while true; do
    echo "Lộc Nguyễn đẹp troai" > locnguyen.txt
    echo "[$(date '+%H:%M:%S')] Đã tạo locnguyen.txt"
    sleep 300
  done
) &
FILE_PID=$!

#########################
# BORE AUTO-RESTART    #
#########################
BORE_DIR="$HOME/.bore"
BORE_BIN="$BORE_DIR/bore"
BORE_LOG="$WORKDIR/bore.log"
BORE_URL_FILE="$WORKDIR/bore_url.txt"

mkdir -p "$BORE_DIR"

if [ ! -f "$BORE_BIN" ]; then
  echo "📥 Đang tải Bore..."
  curl -sL https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C "$BORE_DIR"
  chmod +x "$BORE_BIN"
fi

pkill bore 2>/dev/null || true
rm -f "$BORE_LOG" "$BORE_URL_FILE"
sleep 2

(
  while true; do
    echo "[$(date '+%H:%M:%S')] 🔄 Bore tunnel..." | tee -a "$BORE_LOG"
    
    "$BORE_BIN" local 5900 --to bore.pub 2>&1 | tee -a "$BORE_LOG" | while read line; do
      echo "$line"
      if echo "$line" | grep -q "bore.pub:"; then
        echo "$line" | grep -oP 'bore\.pub:\d+' > "$BORE_URL_FILE"
      fi
    done
    
    echo "[$(date '+%H:%M:%S')] ⚠️  Bore died - restart 2s..." | tee -a "$BORE_LOG"
    sleep 2
  done
) &
BORE_KEEPER_PID=$!

echo -n "⏳ Chờ Bore"
for i in {1..15}; do
  sleep 1
  echo -n "."
  if [ -f "$BORE_URL_FILE" ]; then
    break
  fi
done
echo ""

if [ -f "$BORE_URL_FILE" ]; then
  BORE_ADDR=$(cat "$BORE_URL_FILE")
else
  BORE_ADDR="Chờ..."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌍 VNC: $BORE_ADDR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 RealVNC: $BORE_ADDR"
echo "💡 Check: cat $BORE_URL_FILE"
echo ""

###################################
# TẠO AUTO INSTALL SCRIPT        #
###################################
cat > "$WORKDIR/install.sh" << 'EOFINSTALL'
#!/bin/bash
set -e

echo "🚀 Auto install Arch Linux..."

# Phân vùng
parted /dev/vda --script mklabel gpt
parted /dev/vda --script mkpart primary ext4 1MiB 100%
mkfs.ext4 -F /dev/vda1
mount /dev/vda1 /mnt

# Base system
pacstrap /mnt base linux linux-firmware networkmanager grub sudo

genfstab -U /mnt >> /mnt/etc/fstab

# Chroot config
arch-chroot /mnt /bin/bash << 'CHROOT'
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "archlinux" > /etc/hostname

echo "root:123456" | chpasswd

grub-install /dev/vda
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager

# Desktop + Chrome
pacman -S --noconfirm xorg xfce4 lightdm lightdm-gtk-greeter google-chrome
systemctl enable lightdm

# User
useradd -m -G wheel -s /bin/bash user
echo "user:123456" | chpasswd
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

CHROOT

umount -R /mnt
echo "✅ DONE! Reboot now"
reboot
EOFINSTALL

chmod +x "$WORKDIR/install.sh"

#################
# RUN QEMU     #
#################
if [ ! -f "$FLAG_FILE" ]; then
  echo ""
  echo "⚠️  CÀI ARCH LINUX"
  echo ""
  echo "📋 TRONG ARCH ISO:"
  echo "   Gõ: curl -o i.sh http://10.0.2.2:8000/install.sh && bash i.sh"
  echo "   Chờ 10 phút → tự reboot"
  echo ""
  echo "👉 Sau khi reboot xong, gõ 'xong' ở đây"
  echo ""

  (cd "$WORKDIR" && python3 -m http.server 8000 >/dev/null 2>&1 &)
  HTTP_PID=$!

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=virtio,format=qcow2 \
    -cdrom "$ISO_FILE" \
    -boot order=d \
    -netdev user,id=net0 \
    -device virtio-net,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet &

  QEMU_PID=$!

  while true; do
    read -rp "👉 Gõ 'xong': " DONE
    if [ "$DONE" = "xong" ]; then
      touch "$FLAG_FILE"
      kill "$QEMU_PID" 2>/dev/null || true
      kill "$HTTP_PID" 2>/dev/null || true
      kill "$FILE_PID" 2>/dev/null || true
      kill "$BORE_KEEPER_PID" 2>/dev/null || true
      pkill bore 2>/dev/null || true
      rm -f "$ISO_FILE"
      echo "✅ Done!"
      echo "📝 Login: user / 123456"
      exit 0
    fi
  done

else
  echo "✅ Boot Arch"
  echo "📝 user / 123456"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=virtio,format=qcow2 \
    -boot order=c \
    -netdev user,id=net0 \
    -device virtio-net,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet
fi
