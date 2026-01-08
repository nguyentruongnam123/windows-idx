#!/usr/bin/env bash
set -e

### CONFIG ###
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443&clcid=0x409&culture=en-us&country=US"
ISO_FILE="win11-gamer.iso"

DISK_FILE="win11.qcow2"
DISK_SIZE="64G"

RAM="4G"
CORES="2"

VNC_DISPLAY=":0"
RDP_PORT="3389"

FLAG_FILE="installed.flag"
WORKDIR="/home/user/windows-idx"

### CHECK KVM ###
[ -e /dev/kvm ] || { echo "❌ Không có /dev/kvm"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ Chưa cài qemu"; exit 1; }

### DISK ###
[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"

### ISO (chỉ tải nếu chưa cài) ###
if [ ! -f "$FLAG_FILE" ]; then
  [ -f "$ISO_FILE" ] || wget -O "$ISO_FILE" "$ISO_URL"
fi

echo "🚀 Windows KVM"
echo "🖥️  VNC : localhost:5900"
echo "🖧  RDP : localhost:3389"

############################
# BACKGROUND FILE CREATOR #
############################
mkdir -p "$WORKDIR"

(
  cd "$WORKDIR"
  while true; do
    echo "Lộc Nguyễn đẹp troai" > locnguyen.txt
    echo "[$(date '+%H:%M:%S')] Đã tạo locnguyen.txt"
    sleep 300
  done
) &

FILE_PID=$!

#################
# RUN QEMU     #
#################
if [ ! -f "$FLAG_FILE" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  CHẾ ĐỘ CÀI ĐẶT WINDOWS"
  echo "👉 Sau khi cài xong Windows:"
  echo "👉 Quay lại terminal này, nhập: xong"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
    read -rp "👉 Nhập 'xong' khi đã cài xong Windows: " DONE
    if [ "$DONE" = "xong" ]; then
      echo "✅ Đã xác nhận cài xong Windows"
      touch "$FLAG_FILE"
      echo "🛑 Dừng QEMU..."
      kill "$QEMU_PID"
      echo "🛑 Dừng tiến trình tạo file..."
      kill "$FILE_PID"
      sleep 3
      echo "🧹 Xóa ISO"
      rm -f "$ISO_FILE"
      exit 0
    fi
  done

else
  echo "✅ Windows đã cài – boot từ qcow2"

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
