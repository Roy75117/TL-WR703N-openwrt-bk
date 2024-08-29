# TL-WR703N-openwrt-bk

### This is the backup repo for legacy openwrt rel(lede-17.01.7) of TP-Link TL-WR703N
https://openwrt.org/toh/tp-link/tl-wr703n

#### 1. upgrade extroot to device boot firmware.

**lede-17.01.7-ar71xx-generic-tl-wr703n-v1-squashfs-sysupgrade.bin** is provided for very limited size boot firmware for TP-Link TL-WR703N. This image is built with following pkg by default.
1. block-mount 
2. kmod-fs-f2fs 
3. kmod-usb-storage 
4. mkf2fs 
5. f2fsck

_reference_ : https://www.coldawn.com/how-to-install-lede-on-tl-wr703n-and-enable-extroot/ 

#### 2. overlay with USB Disk 
1. Prepare a USB disk no less than 256MB and connect with TL-WR703N
2. power on TL-WR703N and connect it to your PC with LAN Cable.
3. Set PC ip as 192.168.1.x and connect TL-WR703N with ssh

on PC :
```shell
    ssh root@192.168.1.1
```
4. Check block information. (foud out USB device -> /dev/sdax)

on TL-WR703N :
```
    block info
```
>     /dev/mtdblock2: UUID="9fd43c61-c3f2c38f-13440ce7-53f0d42d" VERSION="4.0" MOUNT="/rom" TYPE="squashfs"
>     /dev/mtdblock3: MOUNT="/overlay" TYPE="jffs2"
>     /dev/sda1: UUID="fdacc9f1-0e0e-45ab-acee-9cb9cc8d7d49" VERSION="1.4" TYPE="ext4"

5. Format USB disk as f2fs.

on TL-WR703N :
```shell
    mkfs.f2fs /dev/sda1
```

6. Edit fstab

on TL-WR703N :
```shell
    block detect > /etc/config/fstab; \
    sed -i s/option$'\t'enabled$'\t'\'0\'/option$'\t'enabled$'\t'\'1\'/ /etc/config/fstab; \
    sed -i s#/mnt/sda1#/overlay# /etc/config/fstab; \
    cat /etc/config/fstab;
```

6. Check fstab

on TL-WR703N :
```shell
    cat /etc/config/fstab
```
> config 'global'
>
>        option  anon_swap       '0'
>        option  anon_mount      '0'
>        option  auto_swap       '1'
>        option  auto_mount      '1'
>        option  delay_root      '5'
>        option  check_fs        '0'
>
> config 'mount'
>
>        option  target  '/overlay'
>        option  uuid    'fdacc9f1-0e0e-45ab-acee-9cb9cc8d7d49'
>        option  enabled '1'

7. Copy /overlay to USB disk(/dev/sda1)

on TL-WR703N :
```shell
    mount /dev/sda1 /mnt ; tar -C /overlay -cvf - . | tar -C /mnt -xf - ; umount /mnt
```

8. Reboot TL-WR703N

on TL-WR703N :
```shell
     reboot
```

9. Check disk information

on TL-WR703N :
```shell
     df -h
```

#### 3. Connect TL-WR703N to internet

Try to connect TL-WR703N to internet. If you have config backup for network, just retore them with scp.

on PC :
```shell
    scp ./rootfs/config/network root@192.168.1.1:/etc/config
    scp ./rootfs/config/wireless root@192.168.1.1:/etc/wireless
    scp ./rootfs/config/firewall root@192.168.1.1:/etc/firewall
```

Power down the device and connect TL-WR703N to internet with LAN cable then power on.
Please make sure TL-WR703N connect to internet and you can ssh into the device.

on PC then TL-WR703N :
```shell
    ssh root@192.168.5.1
    ping 8.8.8.8
```
#### 4. Install backuped pkg (in TL-WR703N)
 To run the luci, you could install the following pkg.

on TL-WR703N :
``` shell
    opkg update
    opkg install luci luci-theme-material
```

Or just restore with **list-installed.txt**. (just check the txt file for what will be installed)

ON PC : 
``` shell
    scp ./rootfs/root/list-installed.txt root@192.168.5.1:/tmp
``` 

on TL-WR703N :
``` shell
    opkg update
    cat /tmp/list-installed.txt | xargs opkg install
```

#### 5. (Option) prepare folder and enable 64MB swap for **6. restore config files for each service** 

on PC :
```shell
    scp ./rootfs/etc/rc.local root@192.168.5.1:/etc/
    scp ./rootfs/etc/freememory.sh root@192.168.5.1:/etc/
```

on TL-WR703N :
``` shell
    chmod +x /etc/freememory.sh
    mkdir -p /root/share/download
    dd if=/dev/zero of=/swapfile bs=1M count=64
    mkswap /swapfile
    swapon /swapfile
```

* set cron task for each two hour

on TL-WR703N :
```shell
    crontab -e
```
>   0 */2 * * 1 /etc/freememory.sh


#### 6. Restore config files for each service
The default service with **list-installed.txt** are the deblow.
1. sshtunnel for socket5 proxy (by openssh client)
2. ttyd (web-based terminal)
3. avahi-daemon (xxx.local)
4. aria2
5. polipo (http proxy)
6. samba
7. ~~adblock~~ (disable by default)

##### adblock
on PC :
``` shell
    scp ./rootfs/etc/config/adblock root@192.168.5.1:/etc/config
```

##### aria
on PC :
``` shell
    scp ./rootfs/etc/config/aria root@192.168.5.1:/etc/config
    scp -r ./rootfs/www/yaaw root@192.168.5.1:/www/
```
default download folder is **/root/share/download**

yaaw url is **http://192.168.5.1/yaaw** or **http://openwrt.local/yaaw**

##### polipo
on PC :
``` shell
    scp ./rootfs/etc/config/polipo root@192.168.5.1:/etc/config
```
http proxy port is **4321**. http proxy is based on socket5 proxy which provied by **sshtunnel**.

Assign http proxy as **http://192.168.5.1:4321** on client side. 

##### samba
on PC :
``` shell
    scp ./rootfs/etc/config/samba root@192.168.5.1:/etc/config
```
guest share folder path is **/root/share**

##### sshtunnel
SSH needs a key pair, and the default tools on OpenWRT are for Dropbear keys, but for sshtunnel we need OpenSSH keys.
Dropbear doesn't support socket5 proxy.

First, a place to store the keys, and create a Dropbear key:

on TL-WR703N :
``` shell
    cd ~
    mkdir .ssh
    chmod 700 .ssh/
    dropbearkey -t rsa -f /root/.ssh/id_dropbear
```
That last command will print the public key to the console, which we can copy and paste into a file:
``` shell
    vi ~/.ssh/id_rsa.pub
```
The same public key can also be copied into ~/.ssh/authorized_keys on ssh server we want to connect to.
``` shell
    scp -p [port] ~/.ssh/id_rsa.pub [account]@[my.ssh.server]:~/.ssh/authorized_keys
```
The Dropbear key needs to be converted, after installing the tool to do that:
``` shell
    opkg install dropbearconvert
    dropbearconvert dropbear openssh ~/.ssh/id_dropbear ~/.ssh/id_rsa
``` 
Now you can log to ssh server without input password.
``` shell
    ssh -p [port] [account]@[my.ssh.server]
``` 

Then to restore sshtunnel config 

on PC :
``` shell
    scp ./rootfs/etc/config/sshtunnel root@192.168.5.1:/etc/config
```
default is raspbian server, check config for more detail.

proxy port is **1234**.

Assign socket v5 proxy as **socket://192.68.5.1:1234**

_reference_ : https://blog.thestateofme.com/2022/10/26/socks-proxy-ssh-tunnels-on-openwrt/

##### ttyd
on PC :
``` shell
    scp ./rootfs/etc/init.d/ttyd root@192.168.5.1:/etc/init.d
```
on TL-WR703N :
```shell
    /etc/init.d/ttyd enable
    /etc/init.d/ttyd start
```
Default port is **8888**. Access with **http://192.168.5.1:8888** or **http://openwrt.local:8888**


### Appendix
#### a. Use dd to restart partition. Use **lsblk** to check the the USB device
```shell
lsblk
```

> NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
> 
> loop0         7:0    0 208.9M  0 loop /dev/shm/mnt
> 
> sda         179:0    0 
>
> └─sda1 

```shell
sudo dd if=./openwrt.sdx1.img of=/dev/sda1 bs=4k status=progress
```

#### b. check file before extend rootfs
```shell
sudo e2fsck -f -y /dev/sda1
```

#### c. extend whole usb storage for rootfs
```shell
sudo resize2fs /dev/sda1
```

#### i. Use `resize2fs -M` to minimize the partition.
```shell
sudo resize2fs -M /dev/sda1
```

#### ii. Use dumpe2fs to check partition (block size, block count)
```shell
sudo dumpe2fs -h /dev/sda
```

```shell
sudo dd if=/dev/sda1 of=./openwrt.sdx1.img bs=4k status=progress count=[block count of dumpe2fs] conv=notrunc,noerror
```

#### iii. Check img content with [mount-img](https://github.com/mafintosh/mount-img)
```shell
mkdir /dev/shm/mnt
mount-img openwrt.sdx1.img /dev/shm/mnt
```
The partition size is 74MB, and the rootfs size is 26MB. 
> /dev/loop0       74M   26M   33M   44% /dev/shm/mnt