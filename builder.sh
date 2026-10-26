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
H4sIAAAAAAACA41XX2/bNhB/tj7FVfbaOIgseUMzLIE7bF2xFWvXoguwhzYzaOlsEZZJhaTseEm+
++4oybJTB9sLLfJ4d7/7y3P/WTyTKrZ5EPiPWWW3M30Lq2UmDUQlxKXRKcR2ayHOcA1xZQ3frD+s
/2rWrTVaO4hXmElxKC6KpLJOFAVENgjwttTGwcefrn6btPIu6qUVeuHXIFjpSjmIHHgYkQal8RbT
M6VtJTP6YUw1RF67+4Rmbp9iqImMuGVQzEMktyprtn2mFTFNku9fvjyz8h+cjJP34F1BSxD0QSFm
mPGRDT5DlHpCrCqy9hru78mXpBWiFZyfn+/RUhjDd8z/CdPKWLnGYgsGrS7WCM5tQRRSWLRQyCVC
qhVRELRhWhIU0rppczglmTJFezKEu6An5/AMCAd6A+O0ENbGxBMPxrFIHemB60twOaqg18M01zAY
05dBVxk6msuAFlLDJlJcByepcE+KGl5Cpon7GBwYsIN6mVYYPASBJQXlVCrpnJi1d0+GhNihWU3W
bpwkQa8Pb9VNJQ0yQliiUVgAw2ENoOetIybQaKnBsr882KNAmn0Ltk8/lBcul2oB5K4GEzncoMi2
kIt1rZ6lEmyoSuLyfl0YLCG6gfDvAREvwl3ax+jSuBG0827t3rAPqMSMglfoBYHUijSRzUr4YDTg
QvjCHL1Xr47KZFoffhZVZoRDdkRC3sHSMkBHhliYG71qPNbp9jAvKK1KsWmqKl4gGxa9IxFMpoUC
8N/6KTO8F3a5tbtjOYO90Gt4/nzPTdGmRhA+cf+xp+q7jyHsrjcg2owyLp3iLQW8yfxCp6IAOp3U
SUFfnBS+5Pi7/ficRD9cnzbJ4K0JB3Qc1uhnlATLRskhlXX2gXNkPzl16SSFcAQb9K0AbGV8/vig
cPFeEBeItJRTbeUkfPaXVJneWPg2Sc5DuEUVlamciXQ5yiV1mpNkfJEko2TIJUOtsy1BbnBxusoK
qXBIrXFLmu0kzHBWLXxd+USeCkNqyyUt1ubTJVIjqRx1MIepCwP2C/HVxqfUX8g62ofEG/TsvSXQ
Bd6Ph+SZP9/+8eu7N+8//PJmsuU661GmUqZV5Jbe5WXQQyvSpldIX3w1osavj2X3BnJyOuzhmkIU
/v7h49V0cCcfJoM7utE/nTyELJIufX2FlNdEpY+Rla6pHk4dNr8Eu7LzHlo0xW7wpkLrMONerQih
l9Q5sckC7/pbFlJoirdYC1nUwgwVrbHgNFAdUVipwfgdvRKF1iXUzx8pF4YaelPdPwa+cMJB59QQ
JhCybV07rovgjaJ6ZLR1MFgwjuBqWyK8oHR3L1hbGwuYUZXQvVFI4csD7t59eO8fNa6fOb9wGWXO
jLuPLrudvamEzffpmuwqxJYya/f4e1tiFhQZfbjddG/t7tH86qFMvmmIj1mPatjEVVmieXy4Qicy
4cTe495gZ50drqZljHbUQ/gde2MoMHuhN2gIzOTw8plH8tV5g/Bso83yCLFF2mpohgwmc1gqqgi7
SalNLTkTlYZPV69BUucmZBlnSNfR2pQoaDKxc9i14lEW542Igx5pKlUgjRA25oRo7wR0gEeF2P8h
pLnjk+ro672fKq0cPym2m93w6Hd+aGo3B57rjglCt1kLE6cizTEW5TIgHCqDmMqSBUWOC2JONSxW
VBinpXBpfjpywrygnk3TG9An3Z3D3QNEr7v59MvlbqzUMPMin8ByNN1bngM79ybJln5o+v5w2t44
cIefJevHdc7MyBHoOkPzANSn95Dm9ajdckM7xVOovO0H07fdSPLN9IClntp9NkDdAnePBw3ovg/x
gRErSmJcoVmgSnk+TTm3aSzKkWbYQlSKwpOFx7TSf4oacPAvFH0yLGYMAAA=
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
