#!/usr/bin/env bash
set -e

### CONFIG ###
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="win11-gamer.iso"

DISK_FILE="/var/win11.qcow2"
DISK_SIZE="500G"

RAM="16G"
CORES="16"

VNC_DISPLAY=":0"
RDP_PORT="3389"

FLAG_FILE="installed.flag"
WORKDIR="$HOME/windows-idx"

### CHECK ###
[ -e /dev/kvm ] || { echo "❌ No /dev/kvm"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ No qemu"; exit 1; }

### PREP ###
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"

if [ ! -f "$FLAG_FILE" ]; then
  [ -f "$ISO_FILE" ] || wget --no-check-certificate \
    -O "$ISO_FILE" "$ISO_URL"
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
rm -f "$BORE_LOG"
sleep 2

# Script tự động restart Bore
(
  while true; do
    echo "[$(date '+%H:%M:%S')] 🔄 Khởi động Bore tunnel..." | tee -a "$BORE_LOG"
    
    "$BORE_BIN" local 5900 --to bore.pub 2>&1 | tee -a "$BORE_LOG" | while read line; do
      echo "$line"
      if echo "$line" | grep -q "bore.pub:"; then
        echo "$line" | grep -oP 'bore\.pub:\d+' > "$BORE_URL_FILE"
      fi
    done
    
    echo "[$(date '+%H:%M:%S')] ⚠️  Bore died - restart sau 2s..." | tee -a "$BORE_LOG"
    sleep 2
  done
) &
BORE_KEEPER_PID=$!

# Đợi lấy URL
echo -n "⏳ Đang chờ Bore"
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
  BORE_ADDR="Chờ khởi động..."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌍 VNC: $BORE_ADDR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 Kết nối RealVNC: $BORE_ADDR"
echo "💡 Nếu die, đợi 2-3s sẽ tự reconnect"
echo "   Kiểm tra URL mới: cat $BORE_URL_FILE"
echo ""

#################
# RUN QEMU     #
#################
if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️  CHẾ ĐỘ CÀI ĐẶT WINDOWS"
  echo "👉 Cài xong quay lại nhập: xong"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=ide,format=qcow2 \
    -cdrom "$ISO_FILE" \
    -boot order=d \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet &

  QEMU_PID=$!

  while true; do
    read -rp "👉 Nhập 'xong': " DONE
    if [ "$DONE" = "xong" ]; then
      touch "$FLAG_FILE"
      kill "$QEMU_PID" 2>/dev/null || true
      kill "$FILE_PID" 2>/dev/null || true
      kill "$BORE_KEEPER_PID" 2>/dev/null || true
      pkill bore 2>/dev/null || true
      rm -f "$ISO_FILE"
      echo "✅ Hoàn tất – lần sau boot thẳng qcow2"
      exit 0
    fi
  done

else
  echo "✅ Windows đã cài – boot thường"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=ide,format=qcow2 \
    -boot order=c \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet
fi
