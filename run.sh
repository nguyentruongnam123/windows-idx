#!/usr/bin/env bash
set -e

### CONFIG ###
ISO_URL="https://onedrive-cf.cloudmini.net/api/raw?path=/Public/Vultr/M%E1%BB%9Bi%201909/Update%200907/2012R2.iso"
ISO_FILE="win11-gamer.iso"

DISK_FILE="win11.qcow2"
DISK_SIZE="64G"

RAM="4G"
CORES="2"
THREADS="1"

VNC_DISPLAY=":0"   # 5900
RDP_PORT="3389"

### CHECK KVM ###
[ -e /dev/kvm ] || { echo "❌ no /dev/kvm"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ no qemu"; exit 1; }

### ISO ###
[ -f "${ISO_FILE}" ] || wget -O "${ISO_FILE}" "${ISO_URL}"

### DISK ###
[ -f "${DISK_FILE}" ] || qemu-img create -f qcow2 "${DISK_FILE}" "${DISK_SIZE}"

# ===== [PHẦN THÊM MỚI: TẠO FILE TỰ ĐỘNG CÀI ĐẶT] =====
echo "[+] Đang chuẩn bị cấu hình tự động cài đặt..."
mkdir -p config_dir
cat > config_dir/autounattend.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <DiskConfiguration>
                <Disk wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Format>NTFS</Format>
                            <Label>Windows</Label>
                            <Letter>C</Letter>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
            </DiskConfiguration>
            <UserData>
                <AcceptEula>true</AcceptEula>
            </UserData>
            <ImageInstall>
                <OSImage>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>1</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
        </component>
    </settings>
</unattend>
EOF

# Tạo một file image chứa cấu hình (dùng định dạng FAT để Windows dễ đọc)
# Nếu máy chưa có mtools, script sẽ cố gắng chạy bằng cách gắn thư mục trực tiếp
# =====================================================

echo "🚀 Windows 11 KVM BIOS + SCSI (LSI)"
echo "🖥️  VNC : localhost:5900"
echo "🖧  RDP : localhost:3389"
NGROK_TOKEN="37Z86uoOADtEYK4BKprMSOYQJGT_xs92nf8f6AJfiZLTu9oN"
NGROK_DIR="$HOME/.ngrok"
NGROK_BIN="$NGROK_DIR/ngrok"
NGROK_CFG="$NGROK_DIR/ngrok.yml"

mkdir -p "$NGROK_DIR"

# ===== INSTALL NGROK (NO SUDO) =====
if [ ! -f "$NGROK_BIN" ]; then
  echo "[+] Installing ngrok..."
  curl -sL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar -xz -C "$NGROK_DIR"
  chmod +x "$NGROK_BIN"
fi

# ===== CREATE CONFIG =====
cat > "$NGROK_CFG" <<EOF
version: "2"
authtoken: $NGROK_TOKEN

tunnels:
  vnc:
    proto: tcp
    addr: 5900
  rdp:
    proto: tcp
    addr: 3389
EOF

# ===== STOP OLD NGROK (SAFE) =====
pkill -f "$NGROK_BIN" 2>/dev/null || true

# ===== START NGROK (NO 4040 API) =====
"$NGROK_BIN" start --all --config "$NGROK_CFG" --log=stdout > "$NGROK_DIR/ngrok.log" 2>&1 &

sleep 6

# ===== PARSE FROM LOG (V3 SAFE) =====
VNC_ADDR=$(grep -oE 'tcp://[^ ]+' "$NGROK_DIR/ngrok.log" | sed 's|tcp://||' | sed -n '1p')
RDP_ADDR=$(grep -oE 'tcp://[^ ]+' "$NGROK_DIR/ngrok.log" | sed 's|tcp://||' | sed -n '2p')

echo "Cong tcp 5900 (VNC) : $VNC_ADDR"
echo "Cong tcp 3389 (RDP) : $RDP_ADDR"

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 8G \
  -machine q35 \
  -drive file=win11.qcow2,if=ide,format=qcow2 \
  -drive file=win11-gamer.iso,index=1,media=cdrom \
  -drive file=fat:rw:config_dir,index=2,format=raw \
  -boot order=d \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -vnc :0 \
  -usb -device usb-tablet \
  -no-reboot &

cd /home/user/windows-idx/ 2>/dev/null || mkdir -p /home/user/windows-idx/ && cd /home/user/windows-idx/
while true
do
    # 1. Tạo file locnguyen.txt với nội dung yêu cầu
    echo "Lộc Nguyễn đẹp troai" > locnguyen.txt
    echo "[$(date '+%H:%M:%S')] Đã tạo file locnguyen.txt"

    # 2. Chờ 5 phút (5 * 60 = 300 giây)
    sleep 300

    # 3. Xóa file
    if [ -f locnguyen.txt ]; then
        rm locnguyen.txt
        echo "[$(date '+%H:%M:%S')] Đã xóa file locnguyen.txt"
    fi

    # 4. Chờ 30 giây trước khi lặp lại
    sleep 30
done
