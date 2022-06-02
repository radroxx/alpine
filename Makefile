SHELL := /bin/sh

.PHONY: all
.ONESHELL:

define alpinepubkey1
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAlEyxkHggKCXC2Wf5Mzx4
nZLFZvU2bgcA3exfNPO/g1YunKfQY+Jg4fr6tJUUTZ3XZUrhmLNWvpvSwDS19ZmC
IXOu0+V94aNgnhMsk9rr59I8qcbsQGIBoHzuAl8NzZCgdbEXkiY90w1skUw8J57z
qCsMBydAueMXuWqF5nGtYbi5vHwK42PffpiZ7G5Kjwn8nYMW5IZdL6ZnMEVJUWC9
I4waeKg0yskczYDmZUEAtrn3laX9677ToCpiKrvmZYjlGl0BaGp3cxggP2xaDbUq
qfFxWNgvUAb3pXD09JM6Mt6HSIJaFc9vQbrKB9KT515y763j5CC2KUsilszKi3mB
HYe5PoebdjS7D1Oh+tRqfegU2IImzSwW3iwA7PJvefFuc/kNIijfS/gH/cAqAK6z
bhdOtE/zc7TtqW2Wn5Y03jIZdtm12CxSxwgtCF1NPyEWyIxAQUX9ACb3M0FAZ61n
fpPrvwTaIIxxZ01L3IzPLpbc44x/DhJIEU+iDt6IMTrHOphD9MCG4631eIdB0H1b
6zbNX1CXTsafqHRFV9XmYYIeOMggmd90s3xIbEujA6HKNP/gwzO6CDJ+nHFDEqoF
SkxRdTkEqjTjVKieURW7Swv7zpfu5PrsrrkyGnsRrBJJzXlm2FOOxnbI2iSL1B5F
rO5kbUxFeZUIDq+7Yv4kLWcCAwEAAQ==
-----END PUBLIC KEY-----
endef
export alpinepubkey1

define alpinepubkey2
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAutQkua2CAig4VFSJ7v54
ALyu/J1WB3oni7qwCZD3veURw7HxpNAj9hR+S5N/pNeZgubQvJWyaPuQDm7PTs1+
tFGiYNfAsiibX6Rv0wci3M+z2XEVAeR9Vzg6v4qoofDyoTbovn2LztaNEjTkB+oK
tlvpNhg1zhou0jDVYFniEXvzjckxswHVb8cT0OMTKHALyLPrPOJzVtM9C1ew2Nnc
3848xLiApMu3NBk0JqfcS3Bo5Y2b1FRVBvdt+2gFoKZix1MnZdAEZ8xQzL/a0YS5
Hd0wj5+EEKHfOd3A75uPa/WQmA+o0cBFfrzm69QDcSJSwGpzWrD1ScH3AK8nWvoj
v7e9gukK/9yl1b4fQQ00vttwJPSgm9EnfPHLAtgXkRloI27H6/PuLoNvSAMQwuCD
hQRlyGLPBETKkHeodfLoULjhDi1K2gKJTMhtbnUcAA7nEphkMhPWkBpgFdrH+5z4
Lxy+3ek0cqcI7K68EtrffU8jtUj9LFTUC8dERaIBs7NgQ/LfDbDfGh9g6qVj1hZl
k9aaIPTm/xsi8v3u+0qaq7KzIBc9s59JOoA8TlpOaYdVgSQhHHLBaahOuAigH+VI
isbC9vmqsThF2QdDtQt37keuqoda2E6sL7PUvIyVXDRfwX7uMDjlzTxHTymvq2Ck
htBqojBnThmjJQFgZXocHG8CAwEAAQ==
-----END PUBLIC KEY-----
endef
export alpinepubkey2


alpine = 3.16
apk_version = 2.10.4
arch = x86_64
#arch = x86

# Базовая система
pkgs  = alpine-base

# Файловая подсистема
pkgs += btrfs-progs e2fsprogs cryptsetup cryptsetup-openrc
pkgs += cifs-utils ntfs-3g nfs-utils

# Сетевая подсистема
pkgs += dhclient nftables nftlb nftables-openrc curl rsync wireguard-tools-wg openvpn
pkgs += lsyncd strongswan strongswan-openrc openvswitch

# Wifi
pkgs += wireless-tools wpa_supplicant hostapd

# SSH and ssl
pkgs += dropbear dropbear-openrc openssh-client gnupg openssl

# utils
pkgs += device-mapper-libs sudo pv minicom unzip tmux mailx tar
pkgs += git ansible-core supervisor bind-tools
pkgs += fail2ban logrotate
pkgs += mqtt-exec
pkgs += samba-server
pkgs += openldap openldap-clients tinyproxy
##pkgs += dovecot
pkgs += exim imap ngircd
pkgs += nginx nginx-mod-http-dav-ext nginx-mod-http-vts nginx-mod-mail nginx-mod-stream

# x86_64 only
pkgs += nginx-mod-http-js

# diagnostic
pkgs += neofetch htop atop iftop mtr iperf3 tcpdump usbutils dmidecode lm-sensors
pkgs += collectd collectd-disk collectd-dns collectd-python collectd-wireless collectd-statsd collectd-snmp collectd-sensors collectd-smart collectd-apcups
pkgs += collectd-postgresql collectd-ping collectd-nginx collectd-network collectd-hddtemp collectd-openvpn collectd-openldap collectd-ovs collectd-rrdtool
pkgs += collectd-pcie_errors collectd-sysevent 

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
	echo "http://dl-cdn.alpinelinux.org/alpine/v${alpine}/main" > $@
	echo "http://dl-cdn.alpinelinux.org/alpine/v${alpine}/community" >> $@
	echo "$$alpinepubkey1" > alpine-$*/etc/apk/keys/alpine-devel@lists.alpinelinux.org-61666e3f.rsa.pub
	echo "$$alpinepubkey2" > alpine-$*/etc/apk/keys/alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub
	@touch $@

alpine-%/etc/issue: apk alpine-%/etc/apk/repositories
	./apk add --root alpine-$* --initdb --initramfs-diskless-boot --update --verbose --no-cache --arch $(arch) alpine-keys
	./apk add --root alpine-$* --initramfs-diskless-boot --update --verbose --no-cache --arch $(arch) $(pkgs)
	./apk add --root alpine-$* --initramfs-diskless-boot --update --verbose --no-cache --arch $(arch) -X http://dl-cdn.alpinelinux.org/alpine/edge/testing proot shadowsocks-libev
	wget -O alpine-$*/usr/lib/python3.9/site-packages/ansible/plugins/filter/encryption.py https://raw.githubusercontent.com/ansible/ansible/v2.12.0/lib/ansible/plugins/filter/encryption.py
	wget -O - https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.1/v2ray-plugin-linux-amd64-v1.3.1.tar.gz | tar -zxO > alpine-$*/usr/bin/v2ray-plugin
	#wget -O - https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.1/v2ray-plugin-linux-386-v1.3.1.tar.gz | tar -zxO > alpine-$*/usr/bin/v2ray-plugin
	chmod +x alpine-$*/usr/bin/v2ray-plugin
	#chmod +rw alpine-$*/bin/bbsuid

alpine-%/boot/vmlinuz-%: alpine-%/etc/issue
	./apk add --root alpine-$* --initramfs-diskless-boot --update --verbose --no-cache --no-scripts --arch $(arch) linux-$*

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

	printf "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet dhcp\niface eth0 inet6 auto\n" > alpine-$*/etc/network/interfaces

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
	chroot alpine-$* /sbin/rc-update add nftables    boot
	chroot alpine-$* /sbin/rc-update add networking  boot

	chroot alpine-$* /sbin/rc-update add mount-ro    shutdown
	chroot alpine-$* /sbin/rc-update add killprocs   shutdown
	chroot alpine-$* /sbin/rc-update add savecache   shutdown 

	chroot alpine-$* /sbin/rc-update add dropbear    default
	chroot alpine-$* /sbin/rc-update add ntpd        default
	chroot alpine-$* /sbin/rc-update add crond       default
	chroot alpine-$* /sbin/rc-update add supervisord default

	chroot alpine-$* /bin/sed -i 's/1000/998/g' /etc/passwd
	chroot alpine-$* /bin/sed -i 's/1000/998/g' /etc/group
	chroot alpine-$* /usr/sbin/adduser -D -u 1000 -s /bin/ash admin
	chroot alpine-$* /usr/sbin/addgroup -g 1000 admin
	chroot alpine-$* /usr/sbin/addgroup admin wheel

	echo 'root:toor' | chroot alpine-$* /usr/sbin/chpasswd
	echo 'admin:admin' | chroot alpine-$* /usr/sbin/chpasswd

	mkdir -p alpine-$*/home/admin/.ssh
	touch $@
	chown 1000:1000 -R alpine-$*/home/admin
	#rm -Rf alpine-$*/lib/firmware/amdgpu
	#rm -Rf alpine-$*/lib/firmware/qed
	#rm -Rf alpine-$*/lib/firmware/mellanox

alpine-%/media/sysroot.squashfs: alpine-%/home/admin/.ssh/authorized_keys
	mksquashfs alpine-$*/ alpine-$*/media/sysroot.squashfs -comp xz -b 1M -no-xattrs -always-use-fragments -noappend \
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
		#lib/ld-musl-i386.so.1
		#lib/libc.musl-x86.so.1

		# loop
		lib/modules
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/modules.dep
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/drivers/
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/drivers/block
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/drivers/block/loop.ko.gz

		# squashfs
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs/overlayfs
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs/overlayfs/overlay.ko.gz
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs/squashfs
		lib/modules/$(shell ls -1 alpine-$*/lib/modules/ | head -n1 | tr -d "\r\n")/kernel/fs/squashfs/squashfs.ko.gz

		media
		media/sysroot.squashfs
	EOF

clean-dist:
	@rm -Rf dist

clean:
	@rm -Rf tmp
	@rm -Rf apk
	@rm -Rf alpine-*
