SHELL := /bin/sh

.PHONY: all
.ONESHELL:

define alpinepubkey
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1yHJxQgsHQREclQu4Ohe
qxTxd1tHcNnvnQTu/UrTky8wWvgXT+jpveroeWWnzmsYlDI93eLI2ORakxb3gA2O
Q0Ry4ws8vhaxLQGC74uQR5+/yYrLuTKydFzuPaS1dK19qJPXB8GMdmFOijnXX4SA
jixuHLe1WW7kZVtjL7nufvpXkWBGjsfrvskdNA/5MfxAeBbqPgaq0QMEfxMAn6/R
L5kNepi/Vr4S39Xvf2DzWkTLEK8pcnjNkt9/aafhWqFVW7m3HCAII6h/qlQNQKSo
GuH34Q8GsFG30izUENV9avY7hSLq7nggsvknlNBZtFUcmGoQrtx3FmyYsIC8/R+B
ywIDAQAB
-----END PUBLIC KEY-----
endef
export alpinepubkey

apk_version = 2.10.4

# Базовая система
pkgs  = alpine-base

# Файловая подсистема
pkgs += btrfs-progs e2fsprogs cryptsetup cryptsetup-openrc cifs-utils ntfs-3g nfs-utils

# Сетевая подсистема
pkgs += dhclient ip6tables ipset curl rsync wireguard-tools-wg openvpn lsyncd

# Wifi
pkgs += wireless-tools wpa_supplicant hostapd

# SSH
pkgs += dropbear dropbear-openrc openssh-client

# utils
pkgs += device-mapper-libs git ansible-base docker-py supervisor sudo pv minicom unzip tmux mailx tar

# diagnostic
pkgs += htop atop iftop mtr iperf3 tcpdump usbutils dmidecode lm-sensors

all: virt lts
virt: dist/initrd-virt dist/vmlinuz-virt
lts: dist/initrd-lts dist/vmlinuz-lts

dist tmp:
	@mkdir -p $@

tmp/apk-tool.tgz: tmp
	wget -q -O $@ https://github.com/alpinelinux/apk-tools/releases/download/v${apk_version}/apk-tools-${apk_version}-x86_64-linux.tar.gz

apk: tmp/apk-tool.tgz
	@tar --strip-components 1 -xzvf $<
	@chmod +x apk

alpine-%/etc/apk/repositories:
	@mkdir -p alpine-$*/etc/apk/keys
	@mkdir -p alpine-$*/lib/apk/db
	echo "http://dl-cdn.alpinelinux.org/alpine/v3.13/main" > $@
	echo "http://dl-cdn.alpinelinux.org/alpine/v3.13/community" >> $@
	echo "$$alpinepubkey" > alpine-$*/etc/apk/keys/alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub
	@touch $@

alpine-%/etc/issue: apk alpine-%/etc/apk/repositories
	./apk add --root alpine-$* --initdb --initramfs-diskless-boot --update --verbose --no-cache alpine-keys
	./apk add --root alpine-$* --initramfs-diskless-boot --update --verbose --no-cache $(pkgs)
	chmod +rw alpine-$*/bin/bbsuid

alpine-%/boot/vmlinuz-%: alpine-%/etc/issue
	./apk add --root alpine-$* --initramfs-diskless-boot --update --verbose --no-cache --no-scripts linux-$*

alpine-%/lib/modules: alpine-%/boot/vmlinuz-%
	@ln -s $(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n") alpine-$*/lib/modules/$(shell uname -r)
	depmod -a -b alpine-$*
	@rm alpine-$*/lib/modules/$(shell uname -r)

alpine-%/home/admin/.ssh/authorized_keys: alpine-%/lib/modules

	@# Enable sudo to wheel group
	chmod +w alpine-$*/etc/sudoers
	echo "root ALL=(ALL) ALL" > alpine-$*/etc/sudoers
	echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> alpine-$*/etc/sudoers
	chmod -w alpine-$*/etc/sudoers

	#chroot alpine-$* /usr/sbin/addgroup -S docker

	chroot alpine-$* /sbin/rc-update add sysfs       sysinit
	chroot alpine-$* /sbin/rc-update add devfs       sysinit
	chroot alpine-$* /sbin/rc-update add mdev        sysinit
	chroot alpine-$* /sbin/rc-update add hwdrivers   sysinit
	chroot alpine-$* /sbin/rc-update add dmesg       sysinit
	chroot alpine-$* /sbin/rc-update add urandom     sysinit
	chroot alpine-$* /sbin/rc-update add cgroups     sysinit

	chroot alpine-$* /sbin/rc-update add modules     boot
	chroot alpine-$* /sbin/rc-update add sysctl      boot
	chroot alpine-$* /sbin/rc-update add dmcrypt     boot
	chroot alpine-$* /sbin/rc-update add swap        boot
	chroot alpine-$* /sbin/rc-update add hostname    boot
	chroot alpine-$* /sbin/rc-update add syslog      boot
	chroot alpine-$* /sbin/rc-update add localmount  boot
	chroot alpine-$* /sbin/rc-update add bootmisc    boot
	chroot alpine-$* /sbin/rc-update add loopback    boot
	chroot alpine-$* /sbin/rc-update add iptables    boot
	chroot alpine-$* /sbin/rc-update add ip6tables   boot
	chroot alpine-$* /sbin/rc-update add ipset       boot
	chroot alpine-$* /sbin/rc-update add networking  boot

	chroot alpine-$* /sbin/rc-update add mount-ro    shutdown
	chroot alpine-$* /sbin/rc-update add killprocs   shutdown
	chroot alpine-$* /sbin/rc-update add savecache   shutdown 

	chroot alpine-$* /sbin/rc-update add dropbear    default
	chroot alpine-$* /sbin/rc-update add ntpd        default
	chroot alpine-$* /sbin/rc-update add crond       default
	chroot alpine-$* /sbin/rc-update add supervisord default

	chroot alpine-$* /usr/sbin/adduser -D -u 1000 admin
	chroot alpine-$* /usr/sbin/addgroup admin wheel

	echo 'root:toor' | chroot alpine-$* /usr/sbin/chpasswd
	echo 'admin:admin' | chroot alpine-$* /usr/sbin/chpasswd

	mkdir -p alpine-$*/home/admin/.ssh
	touch $@
	chown 1000:1000 -R alpine-$*/home/admin

alpine-%/media/sysroot.squashfs: alpine-%/home/admin/.ssh/authorized_keys
	mksquashfs alpine-$*/ alpine-$*/media/sysroot.squashfs -comp gzip -b 1M -no-xattrs -always-use-fragments -noappend \
	-no-recovery -processors 1 -mem 1024M -no-progress -wildcards \
	-e boot -e dev -e proc -e run -e sys -e tmp -e srv -e opt -e var \
	-e init -e "media/*" -e "usr/bin/tcpdump.*" -e usr/bin/ctr

dist/vmlinuz-%: dist alpine-%/lib/modules
	cp alpine-$*/boot/vmlinuz-$* dist/vmlinuz-$*

dist/initrd-%: dist/vmlinuz-% alpine-%/media/sysroot.squashfs
	cp init alpine-$*/init

	@cd alpine-$*

	cat <<- EOF | grep -v "#" | grep -v '^$$' | cpio -H newc -R 0:0 -o > ../$@
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
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/modules.dep
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/drivers/
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/drivers/block
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/drivers/block/loop.ko

		# squashfs
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs/overlayfs
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs/overlayfs/overlay.ko
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs/squashfs
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs/squashfs/squashfs.ko

		media
		media/sysroot.squashfs
	EOF

clean-dist:
	@rm -Rf dist

clean:
	@rm -Rf tmp
	@rm -Rf apk
	@rm -Rf alpine-*
