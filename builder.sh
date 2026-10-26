#!/bin/sh

ROOT=/tmp/root

echo "Build alpine portable dist"

test -d /dist || { echo "/dist dir not found." ; exit 1; }

cd /tmp

# Base system
pkgs="alpine-base kmod"

# fs
pkgs="${pkgs} e2fsprogs cryptsetup cryptsetup-openrc"

# net
pkgs="${pkgs} nftables nftables-openrc curl rsync"

# SSH and ssl
pkgs="${pkgs} dropbear dropbear-openrc openssh-client gnupg openssl"

# utils
pkgs="${pkgs} device-mapper-libs sudo pv minicom unzip tmux mailx tar"
pkgs="${pkgs} git bind-tools logrotate"

# diagnostic
pkgs="${pkgs} neofetch htop atop iftop mtr iperf3 tcpdump usbutils"
pkgs="${pkgs} dmidecode lm-sensors kmon"

alpine_version=
kernel_type=virt
is_install_tools=

while [[ $# -gt 0 ]]; do
	case $1 in
	-a|--alpine)
		alpine_version="$2"
		shift
		shift
		;;
	-k|--kernel)
		kernel_type="$2"
		shift
		shift
		;;
	-i|--install)
		is_install_tools=true
		shift
		;;
	*)
		pkgs="${pkgs} $1"
		shift
		;;
	esac
done

test "${is_install_tools}" = "true" && apk add curl squashfs-tools

test -z "${alpine_version}" && alpine_version=$(curl -s https://dl-cdn.alpinelinux.org | grep -o "v[0-9]\+\.[0-9]\+" | tr -d v | sort -V -r | head -n1)

echo "########################################"
echo "Alpine: ${alpine_version}"
echo "Kernel: ${kernel_type}"
echo "Install pkgs: ${pkgs}"
echo "########################################"

mkdir "${ROOT}"

set -e

echo "Install pkgs ..."

apk fetch -X https://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/main alpine-keys

apk verify alpine-keys-*.apk

apk add \
	--root ${ROOT} --initdb \
	--initramfs-diskless-boot \
	--verbose --no-cache \
	--allow-untrusted \
	alpine-keys-*.apk

apk add \
	--root ${ROOT} --initdb \
	-X https://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/main \
	-X https://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/community \
	--initramfs-diskless-boot --update \
	--verbose --no-cache \
	${pkgs}

apk add \
	--root ${ROOT} --initdb \
	-X https://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/main \
	-X https://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/community \
	--initramfs-diskless-boot --update \
	--verbose --no-cache --no-scripts \
	linux-${kernel_type}

echo "https://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/main" > ${ROOT}/etc/apk/repositories
echo "https://dl-cdn.alpinelinux.org/alpine/v${alpine_version}/community" >> ${ROOT}/etc/apk/repositories

echo "Build dep modules"

#ln -s $(ls -1 ${ROOT}/lib/modules/ | head -n1 | tr -d "\r\n") ${ROOT}/lib/modules/$(uname -r)
chroot ${ROOT} /sbin/depmod -a $(ls -1 ${ROOT}/lib/modules/ | head -n1 | tr -d "\r\n")
#rm ${ROOT}/lib/modules/$(uname -r)

echo "Config sudo"
chmod +w ${ROOT}/etc/sudoers
echo "root ALL=(ALL) ALL" > ${ROOT}/etc/sudoers
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> ${ROOT}/etc/sudoers
chmod -w ${ROOT}/etc/sudoers

echo "Config default network"
printf "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet dhcp\niface eth0 inet6 auto\n" > ${ROOT}/etc/network/interfaces
cat<<EOF > ${ROOT}/etc/nftables.nft
flush ruleset
table inet filter {
	chain input {
		type filter hook input priority filter; policy accept;
	}

	chain forward {
		type filter hook forward priority filter; policy drop;
	}

	chain output {
		type filter hook output priority filter; policy accept;
	}
}
EOF

echo "Config services"
chroot ${ROOT} /sbin/rc-update add sysfs       sysinit
chroot ${ROOT} /sbin/rc-update add devfs       sysinit
chroot ${ROOT} /sbin/rc-update add mdev        sysinit
chroot ${ROOT} /sbin/rc-update add hwdrivers   sysinit
chroot ${ROOT} /sbin/rc-update add dmesg       sysinit
chroot ${ROOT} /sbin/rc-update add cgroups     sysinit

chroot ${ROOT} /sbin/rc-update add modules     boot
chroot ${ROOT} /sbin/rc-update add sysctl      boot
chroot ${ROOT} /sbin/rc-update add dmcrypt     boot
chroot ${ROOT} /sbin/rc-update add swap        boot
chroot ${ROOT} /sbin/rc-update add hostname    boot
chroot ${ROOT} /sbin/rc-update add syslog      boot
chroot ${ROOT} /sbin/rc-update add localmount  boot
chroot ${ROOT} /sbin/rc-update add bootmisc    boot
chroot ${ROOT} /sbin/rc-update add loopback    boot
chroot ${ROOT} /sbin/rc-update add nftables    boot
chroot ${ROOT} /sbin/rc-update add networking  boot

chroot ${ROOT} /sbin/rc-update add mount-ro    shutdown
chroot ${ROOT} /sbin/rc-update add killprocs   shutdown
chroot ${ROOT} /sbin/rc-update add savecache   shutdown 

chroot ${ROOT} /sbin/rc-update add dropbear    default
chroot ${ROOT} /sbin/rc-update add ntpd        default
chroot ${ROOT} /sbin/rc-update add crond       default

echo "Create admin user"

# chroot ${ROOT} /bin/sed -i 's/1000/998/g' /etc/passwd
# chroot ${ROOT} /bin/sed -i 's/1000/998/g' /etc/group
chroot ${ROOT} /usr/sbin/adduser -D -u 1000 -s /bin/ash admin
#chroot ${ROOT} /usr/sbin/addgroup -g 1000 admin
chroot ${ROOT} /usr/sbin/addgroup admin wheel

echo 'root:toor'   | chroot ${ROOT} /usr/sbin/chpasswd
echo 'admin:admin' | chroot ${ROOT} /usr/sbin/chpasswd

mkdir -p ${ROOT}/home/admin/.ssh
chown 1000:1000 -R ${ROOT}/home/admin

echo "Create squashfs"

mksquashfs ${ROOT} ${ROOT}/media/sysroot.squashfs -comp xz -b 1M -no-xattrs -always-use-fragments -noappend \
	-no-recovery -processors 1 -mem 1024M -no-progress -wildcards \
	-e boot -e dev -e proc -e run -e sys -e tmp -e srv -e opt -e var \
	-e init -e "media/*" -e "usr/bin/tcpdump.*"

echo "Create initrd"

cd ${ROOT}
cat <<EOF | base64 -d | gzip -dc > init
H4sIAAAAAAACA41XbW/bNhD+bP2Kq+y1SRBZ8oZmWAJt2LpiK9auRRdgH9rMoKWzTVgmFZLyS5P8
991RkmWnDrYvtMjj3T33ynP/WTyRKrbzIPAfk8puJ3oDy0UuDUQlxKXRGcR2ayHOcQVxZQ3frD+s
/2rWrTVaO4iXmEtxKC6KpLJOFAVENghwU2rj4MPP17+nrbzLemmFXvo1CJa6Ug4iBx5GpEFp3GB2
rrStZE4/jKmGyGt3n9BM7VMMNZERtwyKeYjklmXNts+0JKY0+f7ly3Mrv2A6St6BdwUtQdAHhZhj
zkc2+ARR5gmxqsjaG7i/J1+SVoiWcHFxsUfLYATfMf9HzCpj5QqLLRi0ulghOLcFUUhh0UIhFwiZ
VkRB0IZpSVBI68bN4ZhkygztySncBT05hWdAONAbGGeFsDYmnngwikXmSA/cXIGbowp6PczmGgYj
+jLoKkNHUxnQQmrYRIrr4CQT7klRp1eQa+I+BgcG7KBerhUGD0FgSUE5lko6Jybt3ZNTQuzQLNOV
GyVJ0OvDG3VbSYOMEBZoFBbAcFgD6GnriBQaLTVY9pcHexRIs2/B9umH8sLNpZoBuavBRA43KPIt
zMWqVs9SCTZUJXF5v84MlhDdQvjPgIiX4S7tY3RZ3Ajaebd2b9gHVGJCwSv0jEBqRZrIZiV8MBpw
IXxmjt6PPx6VybQ+/CKq3AiH7IiEvIOlZYCODLEwNXrZeKzT7WFeUlqVYt1UVTxDNix6SyKYTAsF
4L/1U2Z4L+xya3fHcgZ7oTfw/Pmem6J1jSB84v5jT9V3H0PYXW9AtBllXDbGDQW8yfxCZ6IAOk3r
pKAvTgpfcvzdfnxKoh9uzppk8NaEAzoOa/QTSoJFo+SQyjr7wDmyn5y6dJJCOIQ1+lYAtjI+f3xQ
uHgviQtEVsqxtjINn/0tVa7XFr5NkosQNqiiMpMTkS2Gc0md5iQZXSbJMDnlkqHW2ZYgN7g4W+aF
VHhKrXFLmm0a5jipZr6ufCKPhSG15YIWa+fjBVIjqRx1MIeZCwP2C/HVxmfUX8g62ofEG/TsvSXQ
Bd6PTskzf73587e3r9+9//V1uuU661GmUqZV5Jbe1VXQQyuypldIX3w1osavj2X3BjI9O+3hikIU
/vH+w/V4cCcf0sEd3eifpQ8hi6RLX18h5TVR6WNkpWuqh1OHzS/Bruy8h2ZNsRu8rdA6zLlXK0Lo
JXVObLLAu37DQgpN8RYrIYtamKGiNRacBqojCis1GL+jV6LQuoT6+SPlwlBDb6r7p8AXTjjonBpC
CiHb1rXjugheK6pHRlsHgwXjEK63JcILSnf3grW1sYAJVQndG4YUvnnA3bsP7/yjxvUz5Rcup8yZ
cPfRZbezt5Ww8326JrsKsaXM2j3+3paYBUVGH27X3Vu7ezS/eiiTbxriY9ajGtZxVZZoHh8u0Ylc
OLH3uDfYWWeHq2kZwx31EH7H3hgKzF7oNRoCkx5ePvdIvjpvEJ6vtVkcIbZIWw3NkMFkDktFFWHX
GbWpBWei0vDx+hVI6tyELOcM6TpamxIFTSZ2CrtWPMzjeSPioEeaShVII4SNOSHaOwEd4FEh9n8I
ae74pDr6eu+nSivHT4rtZjc8+p0fmtrNgee6Y4LQbVbCxJnI5hiLchEQDpVDTGXJgiLHBTGlGhZL
KoyzUrhsfjZ0sy8vqGfT9AZOELLNlyncPUD0qhtQP1/t5koNEy/zCTBH873lOTB0b5Rs6Ye270+n
7Y0Df/hhsn5dp8yMHIKuNTQvQH16D9m8nrVbbmjHeIqVN/5g/LZrSc4ZH7DUY7tPB6h74O71oAnd
NyI+MGJJWYxLNDNUGQ+oGSc3zUVzpCG2EJWi+OThMa30p6IGHPwL6g7EoGcMAAA=
EOF
chmod +x init

kernel_version=$(ls -1 ${ROOT}/lib/modules/ | head -n1 | tr -d "\r\n")

cat <<- EOF | grep -v "#" | grep -v '^$$' | cpio -H newc -R 0:0 -o > /dist/initrd-${kernel_version}-$(uname -m)
# BusyBox
init
bin
bin/busybox
bin/sh
lib
lib/ld-musl-x86_64.so.1
lib/libc.musl-x86_64.so.1

# loop
lib/modules
lib/modules/${kernel_version}
lib/modules/${kernel_version}/modules.dep
lib/modules/${kernel_version}/kernel
lib/modules/${kernel_version}/kernel/drivers/
lib/modules/${kernel_version}/kernel/drivers/block
lib/modules/${kernel_version}/kernel/drivers/block/loop.ko.gz

# squashfs
lib/modules/${kernel_version}/kernel/fs
lib/modules/${kernel_version}/kernel/fs/overlayfs
lib/modules/${kernel_version}/kernel/fs/overlayfs/overlay.ko.gz
lib/modules/${kernel_version}/kernel/fs/squashfs
lib/modules/${kernel_version}/kernel/fs/squashfs/squashfs.ko.gz

media
media/sysroot.squashfs
EOF

cp boot/vmlinuz-virt /dist/vmlinuz-${kernel_version}-$(uname -m)

echo "Done"
