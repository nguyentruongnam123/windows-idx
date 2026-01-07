#!/usr/bin/env bash
set -e

### CONFIG ###
ISO_URL="https://onedrive-cf.cloudmini.net/api/raw?path=/Public/Vultr/M%E1%BB%9Bi%201909/Update%200907/Win10_ltsc_x64FRE_en-us.iso"
ISO_FILE="win11-gamer.iso"

DISK_FILE="win11.qcow2"
DISK_SIZE="64G"

RAM="8G"
CORES="4"
THREADS="2"

VNC_DISPLAY=":0"   # 5900
RDP_PORT="3389"

### CHECK KVM ###
[ -e /dev/kvm ] || { echo "❌ no /dev/kvm"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ no qemu"; exit 1; }

### ISO ###
[ -f "${ISO_FILE}" ] || wget -O "${ISO_FILE}" "${ISO_URL}"

### DISK ###
[ -f "${DISK_FILE}" ] || qemu-img create -f qcow2 "${DISK_FILE}" "${DISK_SIZE}"

echo "🚀 Windows 11 KVM BIOS + SCSI (LSI)"
echo "🖥️  VNC : localhost:5900"
echo "🖧  RDP : localhost:3389"
NGROK_TOKEN="37Z86uoOADtEYK4BKprMSOYQJGT_xs92nf8f6AJfiZLTu9oN"

# ===== CHECK NGROK =====
if ! command -v ngrok >/dev/null 2>&1; then
  wget -q -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  tar -xzf ngrok.tgz
  chmod +x ngrok
  mv ngrok /usr/local/bin/
  rm -f ngrok.tgz
fi

# ===== ADD TOKEN =====
ngrok config add-authtoken "$NGROK_TOKEN" >/dev/null 2>&1

# ===== START NGROK BACKGROUND =====
ngrok tcp 5900 --log=stdout > /tmp/ngrok5900.log 2>&1 &
ngrok tcp 3389 --log=stdout > /tmp/ngrok3389.log 2>&1 &

# ===== WAIT FOR TUNNELS =====
sleep 5

# ===== GET ENDPOINTS =====
TUNNELS=$(curl -s http://127.0.0.1:4040/api/tunnels)

VNC_ADDR=$(echo "$TUNNELS" | grep -oE 'tcp://[^"]+' | sed 's/tcp:\/\///' | sed -n '1p')
RDP_ADDR=$(echo "$TUNNELS" | grep -oE 'tcp://[^"]+' | sed 's/tcp:\/\///' | sed -n '2p')

# ===== OUTPUT =====
echo "Cong tcp 5900 (VNC) : $VNC_ADDR"
echo "Cong tcp 3389 (RDP) : $RDP_ADDR"

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 8 \
  -m 16G \
  -machine q35 \
  -drive file=/win11.qcow2,if=ide,format=qcow2 \
  -cdrom /win11-gamer.iso \
  -boot order=d \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -vnc :0 \
  -usb -device usb-tablet 

