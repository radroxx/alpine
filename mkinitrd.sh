#!/bin/sh

OLD_PWD=${PWD}

cp init /init

cd /

KERNEL=$( ls -1 /lib/modules/ | head -n1 | tr -d "\r\n" )

cat << EOF | grep -v "#" | grep -v "^$" | cpio -v -H newc -R 0:0 -o > ${OLD_PWD}/dist/initrd-${KERNEL}
# BusyBox
/init
/bin
/bin/busybox
/bin/sh
/lib
/lib/ld-musl-x86_64.so.1
/lib/libc.musl-x86_64.so.1

/lib/modules
/lib/modules/${KERNEL}
/lib/modules/${KERNEL}/modules.dep
/lib/modules/${KERNEL}/kernel
/lib/modules/${KERNEL}/kernel/drivers/
/lib/modules/${KERNEL}/kernel/drivers/block
/lib/modules/${KERNEL}/kernel/drivers/block/loop.ko

# squashfs
/lib/modules/${KERNEL}/kernel/fs
/lib/modules/${KERNEL}/kernel/fs/overlayfs
/lib/modules/${KERNEL}/kernel/fs/overlayfs/overlay.ko
/lib/modules/${KERNEL}/kernel/fs/squashfs
/lib/modules/${KERNEL}/kernel/fs/squashfs/squashfs.ko

/media
/media/sysroot.squashfs
EOF
