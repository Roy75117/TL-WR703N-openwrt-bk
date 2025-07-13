# TL-WR703N OpenWrt Backup Repository

This repository provides a backup for the legacy OpenWrt release (LEDE 17.01.7) for the TP-Link TL-WR703N router.  
For more details, refer to the official OpenWrt documentation: [TP-Link TL-WR703N](https://openwrt.org/toh/tp-link/tl-wr703n).

---

## Table of Contents
- [1. Upgrade to Extroot for Boot Firmware](#1-upgrade-to-extroot-for-boot-firmware)
- [2. Configure Overlay with USB Disk](#2-configure-overlay-with-usb-disk)
- [3. Connect TL-WR703N to the Internet](#3-connect-tl-wr703n-to-the-internet)
- [4. Install Backup Packages](#4-install-backup-packages)
- [5. Enable Swap (Optional)](#5-enable-swap-optional)
- [6. Restore Configuration Files for Services](#6-restore-configuration-files-for-services)
- [Appendix](#appendix)
  - [A. Configure LED for Data Transmission](#a-configure-led-for-data-transmission)
  - [B. Restore Partition with `dd`](#b-restore-partition-with-dd)
  - [C. Check Filesystem Before Extending Rootfs](#c-check-filesystem-before-extending-rootfs)
  - [D. Extend USB Storage for Rootfs](#d-extend-usb-storage-for-rootfs)
  - [E. Minimize Partition](#e-minimize-partition)
  - [F. Check Partition Details](#f-check-partition-details)
  - [G. Mount and Inspect Image Content](#g-mount-and-inspect-image-content)

---

## 1. Upgrade to Extroot for Boot Firmware

The TP-Link TL-WR703N has only 4MB of flash storage, limiting official stable releases with LuCI to [Barrier Breaker 14.07](https://openwrt.org/releases/14.07/notes-14.07). However, this release is outdated and lacks support for many packages.

The latest supported release for TL-WR703N is **LEDE 17.01.7**. To use it with extroot, you must build a custom image using the [OpenWrt ImageBuilder](https://openwrt.org/docs/guide-user/additional-software/imagebuilder) to include only extroot-related packages.

The provided image, **[lede-17.01.7-ar71xx-generic-tl-wr703n-v1-squashfs-sysupgrade.bin](lede-17.01.7-ar71xx-generic-tl-wr703n-v1-squashfs-sysupgrade.bin)**, includes the following packages for extroot support:
- `block-mount`
- `kmod-fs-f2fs`
- `kmod-usb-storage`
- `mkf2fs`
- `f2fsck`

After setting up extroot with a USB disk (minimum 256MB), you can install LuCI and other packages to enhance functionality.

**Reference**: [How to Install LEDE on TL-WR703N and Enable Extroot](https://www.coldawn.com/how-to-install-lede-on-tl-wr703n-and-enable-extroot/)

---

## 2. Configure Overlay with USB Disk

Follow these steps to set up extroot using a USB disk:

1. **Prepare USB Disk**  
   Connect a USB disk (minimum 256MB) to the TL-WR703N.

2. **Power On and Connect**  
   Power on the TL-WR703N and connect it to your PC via a LAN cable.

3. **Set PC IP and SSH**  
   Configure your PC’s IP to `192.168.1.x` and connect to the TL-WR703N via SSH:
   ```shell
   ssh root@192.168.1.1
   ```

4. **Check Block Information**  
   Identify the USB device (e.g., `/dev/sda1`):
   ```shell
   block info
   ```
   **Example Output**:
   ```
   /dev/mtdblock2: UUID="9fd43c61-c3f2c38f-13440ce7-53f0d42d" VERSION="4.0" MOUNT="/rom" TYPE="squashfs"
   /dev/mtdblock3: MOUNT="/overlay" TYPE="jffs2"
   /dev/sda1: UUID="fdacc9f1-0e0e-45ab-acee-9cb9cc8d7d49" VERSION="1.4" TYPE="ext4"
   ```

5. **Format USB Disk as F2FS**  
   ```shell
   mkfs.f2fs /dev/sda1
   ```

6. **Edit `fstab`**  
   Configure the filesystem table to enable extroot:
   ```shell
   block detect > /etc/config/fstab
   sed -i s/option$'\t'enabled$'\t'\'0\'/option$'\t'enabled$'\t'\'1\'/ /etc/config/fstab
   sed -i s#/mnt/sda1#/overlay# /etc/config/fstab
   cat /etc/config/fstab
   ```
   **Expected Output**:
   ```
   config 'global'
       option anon_swap '0'
       option anon_mount '0'
       option auto_swap '1'
       option auto_mount '1'
       option delay_root '5'
       option check_fs '0'

   config 'mount'
       option target '/overlay'
       option uuid 'fdacc9f1-0e0e-45ab-acee-9cb9cc8d7d49'
       option enabled '1'
   ```

7. **Copy Overlay to USB Disk**  
   Mount the USB disk and copy the overlay:
   ```shell
   mount /dev/sda1 /mnt
   tar -C /overlay -cvf - . | tar -C /mnt -xf -
   umount /mnt
   ```

8. **Reboot the Device**  
   ```shell
   reboot
   ```

9. **Verify Disk Information**  
   Check the filesystem usage:
   ```shell
   df -h
   ```

---

## 3. Connect TL-WR703N to the Internet

To connect the TL-WR703N to the internet, restore network configurations or configure manually.

1. **Restore Network Configurations (Optional)**  
   If you have a configuration backup, restore it using SCP:
   ```shell
   scp ./rootfs/etc/config/network root@192.168.1.1:/etc/config/
   scp ./rootfs/etc/config/wireless root@192.168.1.1:/etc/config/
   scp ./rootfs/etc/config/firewall root@192.168.1.1:/etc/config/
   scp ./rootfs/etc/config/system root@192.168.1.1:/etc/config/
   ```

2. **Connect to the Internet**  
   Power off the device, connect it to the internet via a LAN cable, and power it back on.

3. **Verify Connectivity**  
   SSH into the device (assuming the IP is now `192.168.5.1`) and test internet access:
   ```shell
   ssh root@192.168.5.1
   ping 8.8.8.8
   ```

---

## 4. Install Backup Packages

To enable LuCI or other packages, install them on the TL-WR703N after extroot setup.

1. **Install LuCI**  
   Update the package list and install LuCI with a theme:
   ```shell
   opkg update
   opkg install luci luci-theme-material
   ```

2. **Restore Packages from `list-installed.txt`**  
   Copy the package list and install all listed packages:
   ```shell
   # On PC
   scp ./rootfs/root/list-installed.txt root@192.168.5.1:/tmp
   # On TL-WR703N
   opkg update
   cat /tmp/list-installed.txt | xargs opkg install
   ```

---

## 5. Enable Swap (Optional)

To improve performance, enable a 64MB swap file.

1. **Copy Scripts**  
   Transfer necessary scripts to the device:
   ```shell
   # On PC
   scp ./rootfs/etc/rc.local root@192.168.5.1:/etc/
   scp ./rootfs/etc/freememory.sh root@192.168.5.1:/etc/
   ```

2. **Configure Swap**  
   Set up the swap file and make the script executable:
   ```shell
   chmod +x /etc/freememory.sh
   mkdir -p /root/share/download
   dd if=/dev/zero of=/swapfile bs=1M count=64
   mkswap /swapfile
   swapon /swapfile
   ```

3. **Schedule Cron Task**  
   Add a cron job to run `freememory.sh` every two hours:
   ```shell
   crontab -e
   ```
   Add the following line:
   ```
   0 */2 * * * /etc/freememory.sh
   ```

---

## 6. Restore Configuration Files for Services

The following services are included in the `list-installed.txt` backup:
1. `sshtunnel` (SOCKS5 proxy via OpenSSH)
2. `ttyd` (web-based terminal)
3. `avahi-daemon` (zeroconf, e.g., `tl-wr703n.local`)
4. `aria2` (download manager)
5. `polipo` (HTTP proxy)
6. `samba` (file sharing)
7. `adblock` (disabled by default)

### Adblock
Restore the adblock configuration:
```shell
# On PC
scp ./rootfs/etc/config/adblock root@192.168.5.1:/etc/config
```

### Aria2
Restore Aria2 configuration and web interface (YAAW):
```shell
# On PC
scp ./rootfs/etc/config/aria root@192.168.5.1:/etc/config
scp -r ./rootfs/www/yaaw root@192.168.5.1:/www/
```
- **Default Download Folder**: `/root/share/download`
- **YAAW URL**: `http://192.168.5.1/yaaw` or `http://tl-wr703n.local/yaaw`

### Polipo
Restore the Polipo HTTP proxy configuration:
```shell
# On PC
scp ./rootfs/etc/config/polipo root@192.168.5.1:/etc/config
```
- **HTTP Proxy Port**: `4321`
- **Configuration**: Set the HTTP proxy to `http://192.168.5.1:4321` on the client. Polipo relies on the SOCKS5 proxy provided by `sshtunnel`.

### Samba
Restore the Samba configuration for file sharing:
```shell
# On PC
scp ./rootfs/etc/config/samba root@192.168.5.1:/etc/config
```
- **Guest Share Folder**: `/root/share`

### SSH Tunnel
The `sshtunnel` service requires OpenSSH keys for SOCKS5 proxy support, as Dropbear does not support SOCKS5.

1. **Create SSH Key Storage**  
   ```shell
   cd ~
   mkdir .ssh
   chmod 700 .ssh/
   dropbearkey -t rsa -f /root/.ssh/id_dropbear
   ```

2. **Extract Public Key**  
   The `dropbearkey` command outputs the public key. Copy it to a file:
   ```shell
   vi ~/.ssh/id_rsa.pub
   ```

3. **Copy Public Key to SSH Server**  
   Transfer the public key to the SSH server’s `authorized_keys`:
   ```shell
   scp -p [port] ~/.ssh/id_rsa.pub [account]@[my.ssh.server]:~/.ssh/authorized_keys
   ```

4. **Convert Dropbear Key to OpenSSH**  
   Install the conversion tool and convert the key:
   ```shell
   opkg install dropbearconvert
   dropbearconvert dropbear openssh ~/.ssh/id_dropbear ~/.ssh/id_rsa
   ```

5. **Test SSH Connection**  
   Verify passwordless login:
   ```shell
   ssh -p [port] [account]@[my.ssh.server]
   ```

6. **Restore SSH Tunnel Configuration**  
   ```shell
   # On PC
   scp ./rootfs/etc/config/sshtunnel root@192.168.5.1:/etc/config
   ```
   - **Default Proxy Port**: `1234`
   - **SOCKS5 Proxy**: `socks://192.168.5.1:1234`
   - **Reference**: [SOCKS Proxy SSH Tunnels on OpenWrt](https://blog.thestateofme.com/2022/10/26/socks-proxy-ssh-tunnels-on-openwrt/)

### TTYD
Restore and enable the web-based terminal:
```shell
# On PC
scp ./rootfs/etc/init.d/ttyd root@192.168.5.1:/etc/init.d
# On TL-WR703N
/etc/init.d/ttyd enable
/etc/init.d/ttyd start
```
- **Default Port**: `800`
- **Access**: `http://192.168.5.1:800` or `http://tl-wr703n.local:800`

### File Browser
LuCI provides a read-only file browser at:  
`http://192.168.5.1/cgi-bin/luci/admin/filebrowser`

To enable a second `uhttpd` instance with directory listing:
```shell
# On PC
scp ./rootfs/etc/config/uhttp root@192.168.5.1:/etc/config
# On TL-WR703N
/etc/init.d/uhttp restart
```
- **Default Port**: `8080`
- **Access**: `http://192.168.5.1:8080`  
- **Reference**: [OpenWrt Forum](https://forum.archive.openwrt.org/viewtopic.php?id=26073)

---

## Appendix

### A. Configure LED for Data Transmission
Configure the system LED to blink on data transmission.

1. Navigate to **System** > **LED Configuration** in LuCI.
2. Set the following:
   - **LED Name**: `tp-link:blue:system`
   - **Trigger**: `netdev`
   - **Device**: `eth0`
   - **Trigger Mode**: Enable **Transmit**

3. Alternatively, edit `/etc/config/system`:
   ```
   config led
       option default '0'
       option sysfs 'tp-link:blue:system'
       option trigger 'netdev'
       option dev 'eth0'
       option mode 'tx'
   ```

### B. Restore Partition with `dd`
Check USB device details:
```shell
lsblk
```
**Example Output**:
```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0 208.9M  0 loop /dev/shm/mnt
sda         179:0    0
└─sda1
```
Restore the partition:
```shell
sudo dd if=./openwrt.sdx1.img of=/dev/sda1 bs=4k status=progress
```

### C. Check Filesystem Before Extending Rootfs
```shell
sudo e2fsck -f -y /dev/sda1
```

### D. Extend USB Storage for Rootfs
```shell
sudo resize2fs /dev/sda1
```

### E. Minimize Partition
```shell
sudo resize2fs -M /dev/sda1
```

### F. Check Partition Details
Inspect block size and count:
```shell
sudo dumpe2fs -h /dev/sda
```
Backup the partition:
```shell
sudo dd if=/dev/sda1 of=./openwrt.sdx1.img bs=4k status=progress count=[block count of dumpe2fs] conv=notrunc,noerror
```

### G. Mount and Inspect Image Content
Use [mount-img](https://github.com/mafintosh/mount-img) to inspect the image:
```shell
mkdir /dev/shm/mnt
mount-img openwrt.sdx1.img /dev/shm/mnt
```
**Example Output**:
```
/dev/loop0       74M   26M   33M   44% /dev/shm/mnt
```
