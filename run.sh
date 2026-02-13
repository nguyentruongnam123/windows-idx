#!/usr/bin/env bash
set -e

### CONFIG ###
ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04.1-desktop-amd64.iso"
ISO_FILE="ubuntu24.iso"

DISK_FILE="/var/ubuntu.qcow2"
DISK_SIZE="100G"

RAM="4G"
CORES="4"

VNC_DISPLAY=":0"

FLAG_FILE="installed.flag"
WORKDIR="$HOME/ubuntu-vm"

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
    echo "📥 Đang tải Ubuntu 24.04 Desktop (6.1GB)..."
    echo "💡 Có thể mất 10-20 phút..."
    
    wget --continue --no-check-certificate --show-progress \
      -O "$ISO_FILE" "$ISO_URL" || \
    wget --continue --no-check-certificate --show-progress \
      -O "$ISO_FILE" "https://mirror.us.leaseweb.net/ubuntu-releases/24.04/ubuntu-24.04.1-desktop-amd64.iso" || \
    wget --continue --no-check-certificate --show-progress \
      -O "$ISO_FILE" "https://mirror.arizona.edu/ubuntu-releases/24.04/ubuntu-24.04.1-desktop-amd64.iso"
    
    echo "✅ Tải xong!"
    ls -lh "$ISO_FILE"
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

#################
# RUN QEMU     #
#################
if [ ! -f "$FLAG_FILE" ]; then
  echo ""
  echo "⚠️  CHẾ ĐỘ CÀI UBUNTU 24.04"
  echo ""
  echo "📋 TRONG VNC:"
  echo "   1. Click 'Try or Install Ubuntu'"
  echo "   2. Chọn ngôn ngữ → Next"
  echo "   3. Keyboard layout → Next"
  echo "   4. 'Install Ubuntu' → Next"
  echo "   5. Wireless: Skip"
  echo "   6. Updates: 'Normal installation'"
  echo "   7. Disk: 'Erase disk and install'"
  echo "   8. Timezone → Next"
  echo "   9. Tạo user:"
  echo "      Name: user"
  echo "      Password: 123456"
  echo "   10. Chờ cài (10-15 phút)"
  echo "   11. Restart khi xong"
  echo ""
  echo "👉 Sau khi restart xong, gõ 'xong' ở đây"
  echo ""

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
    -usb -device usb-tablet \
    -vga virtio &

  QEMU_PID=$!

  while true; do
    read -rp "👉 Gõ 'xong': " DONE
    if [ "$DONE" = "xong" ]; then
      touch "$FLAG_FILE"
      kill "$QEMU_PID" 2>/dev/null || true
      kill "$FILE_PID" 2>/dev/null || true
      kill "$BORE_KEEPER_PID" 2>/dev/null || true
      pkill bore 2>/dev/null || true
      rm -f "$ISO_FILE"
      echo "✅ Done!"
      echo "📝 Login: user / 123456"
      echo "🌐 Chrome đã có sẵn!"
      exit 0
    fi
  done

else
  echo "✅ Boot Ubuntu 24.04"
  echo "📝 Login: user / 123456"
  echo "🌐 Chrome/Firefox có sẵn"

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
    -usb -device usb-tablet \
    -vga virtio
fi
