# alpine
Simple Alpine linux in ram + docker.

[![Build Status](https://cloud.drone.io/api/badges/radroxx/alpine/status.svg?ref=refs/heads/master)](https://cloud.drone.io/radroxx/alpine)

## How to create config
### Create preboot script
Save next script to file preboot
```sh
#!/bin/sh

# Set root password
echo 'root:${SECRET_PASSWORD}' | chpasswd -e

# Set hostname
hostname localhost
```
Create initrd
```sh
ls preboot | cpio -H newc -R 0:0 -o > preboot_initrd
```

Add preboot config to system initrd
```sh
cat initrd-5.1.12-virt preboot_initrd > my_custom_initrd
```

### How to change root password
```sh
PASSWORD=my_super_duper_password

SALT=$(dd if=/dev/urandom bs=512 count=1 | sha512sum | tr -d ' -')
SECRET_PASSWORD=$(openssl passwd -6 -salt "${SALT}" "${PASSWORD}")

echo "please add next string to preboot script"
echo ""
echo "echo 'root:${SECRET_PASSWORD}' | chpasswd -e"
```

### How to boot in qemu
```sh
qemu-system-x86_64 -m 512M -serial stdio -append "console=ttyS0" -kernel vmlinuz-virt -initrd my_custom_initrd
```
