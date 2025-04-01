#!/bin/bash

# =====================================
# 自动挂载新硬盘（支持分区、格式化、fstab）
# 使用方法：
#   sudo ./auto_mount.sh /dev/sdX /mnt/your_path ext4
# 参数说明：
#   $1 = 硬盘设备名，例如 /dev/sdb
#   $2 = 挂载点路径，例如 /mnt/data
#   $3 = 文件系统类型，默认 ext4（可选：xfs、btrfs）
# =====================================

# Help 信息
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "用法: sudo ./auto_mount.sh [设备] [挂载点] [文件系统类型]"
    echo
    echo "参数："
    echo "  设备              要挂载的磁盘设备（例如：/dev/sdb）"
    echo "  挂载点            挂载路径（例如：/mnt/data）"
    echo "  文件系统类型      可选，默认 ext4（也可为 xfs, btrfs 等）"
    echo
    echo "示例："
    echo "  sudo ./auto_mount.sh /dev/sdb /mnt/data ext4"
    echo "  sudo ./auto_mount.sh /dev/sdc /data_disk xfs"
    echo
    echo "注意：此脚本会自动分区、格式化磁盘，并写入 /etc/fstab 自动挂载。"
    exit 0
fi

# 参数解析
DISK_DEV=${1:-/dev/sdb}
MOUNT_POINT=${2:-/mnt/data}
FS_TYPE=${3:-ext4}

echo "设备:        $DISK_DEV"
echo "挂载路径:    $MOUNT_POINT"
echo "文件系统:    $FS_TYPE"

# 校验设备是否存在
if [ ! -b "$DISK_DEV" ]; then
    echo "错误：设备 $DISK_DEV 不存在"
    exit 1
fi

PARTITION="${DISK_DEV}1"
if [ ! -b "$PARTITION" ]; then
    echo "分区不存在，开始创建分区..."
    echo -e "n\np\n1\n\n\nw" | sudo fdisk "$DISK_DEV"
    sudo partprobe "$DISK_DEV"
    sleep 2
else
    echo "已存在分区：$PARTITION"
fi

# 格式化
echo "正在格式化为 $FS_TYPE ..."
sudo mkfs.$FS_TYPE -F "$PARTITION"

# 挂载
echo "创建挂载点 $MOUNT_POINT（如果不存在）"
sudo mkdir -p "$MOUNT_POINT"

echo "挂载分区到挂载点"
sudo mount "$PARTITION" "$MOUNT_POINT"

# fstab 持久化
UUID=$(sudo blkid -s UUID -o value "$PARTITION")
FSTAB_LINE="UUID=$UUID $MOUNT_POINT $FS_TYPE defaults 0 2"

if grep -q "$UUID" /etc/fstab; then
    echo "fstab 中已存在该挂载项，跳过写入"
else
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
    echo "已添加到 /etc/fstab"
fi

# 验证挂载是否生效
echo "验证挂载是否生效..."
sudo umount "$MOUNT_POINT"
sudo mount -a

echo "挂载完成。现在你可以使用：$MOUNT_POINT"
