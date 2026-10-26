# Portable alpine
Simple Alpine linux in ram.

## How to build image

```
docker run --rm -i -v $PWD:/dist alpine:3.24 /bin/sh /dist/builder.sh -i -k virt
```

Default password `root:toor` and `admin:admin`


## How to create custom image
```
docker run --rm -i -v $PWD:/dist alpine:3.24 /bin/sh /dist/builder.sh -i zfs-virt zfs
```

## How to generate encrypted password
```sh
PASSWORD=my_super_duper_password

SALT=$(dd if=/dev/urandom bs=512 count=1 | sha512sum | tr -d ' -')
SECRET_PASSWORD=$(openssl passwd -6 -salt "${SALT}" "${PASSWORD}")

echo "please add next string to preboot script"
echo ""
echo "echo 'root:${SECRET_PASSWORD}' | chpasswd -e"
```

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

### Create initrd with preboot script
```sh
cp initrd-6.18.58-0-virt-x86_64 my-custom-initrd \
  && ls preboot | cpio -H newc -R 0:0 -o >> my-custom-initrd
```


## How to boot custom image in qemu
```sh
qemu-system-x86_64 \
	-cpu host -enable-kvm -smp 1,cores=1 \
	-m 1024M \
	-nographic \
	-netdev user,id=net0,hostfwd=tcp::2222-:22 \
	-device virtio-net-pci,netdev=net0 \
	-kernel vmlinuz-6.18.58-0-virt-x86_64 -initrd my-custom-initrd \
	-append "console=ttyS0"
```
### How to exit from qemu
```sh
poweroff
```

# Examples

## Image with zfs storage system and samba share
### Create custom image
```
docker run --rm -i -v $PWD:/dist alpine:3.24 \
  /bin/sh /dist/builder.sh -i zfs-virt zfs \
  zfs zfs-openrc samba-server \
  samba-server-openrc samba-common-tools
```
### Create custom preboot script
Save it to file with name `preboot`
```
#!/bin/sh

# Enable zfs module
echo "zfs" > /etc/modules-load.d/01-zfs

# Enable zfs services
rc-update add zfs-import default
rc-update add zfs-mount default

# Enable find all pools
sed -i "s/ZPOOL_IMPORT_ALL_VISIBLE=.*/ZPOOL_IMPORT_ALL_VISIBLE='yes'/g" /etc/conf.d/zfs

# Config nft
cat<<EOF > /etc/nftables.nft
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

# Config samba
mkdir -p /var/log/samba/
mkdir -p /var/lib/samba/private
chmod 700 /var/lib/samba/private

cat <<EOF > /etc/samba/smb.conf
[global]
	server role = standalone server
	workgroup = WORKGROUP
	security = user
	map to guest = never

	# only smb3
	server min protocol = SMB3
	disable netbios = yes
	smb ports = 445

	# speed
	server multi channel support = yes
	use sendfile = yes
	aio read size = 1
	aio write size = 1
	min receivefile size = 16384
	smb encrypt = off

	load printers = no
	printing = bsd
	printcap name = /dev/null
	disable spoolss = yes
	log level = 0
	max log size = 1000
[share]
	path = /data/share
	valid users = admin
	read only = no
	force user = admin
	create mask = 0644
	directory mask = 0755
EOF

rc-update add samba default

# Change passwords from cmdline
set -f
for arg in $(cat /proc/cmdline); do
	case "$arg" in
		admin_passwd=*)
			echo "Change admin password"
			echo "admin:${arg#admin_passwd=}" | chpasswd
			;;
		smb_passwd=*)
			echo "Change smb admin password"
			printf '%s\n%s\n' "${arg#smb_passwd=}" "${arg#smb_passwd=}" | smbpasswd -a -s admin
			;;
	esac
done
set +f
```
Create custom initrd image
```
cp initrd-6.18.58-0-virt-x86_64 my-custom-initrd \
  && ls preboot | cpio -H newc -R 0:0 -o >> my-custom-initrd
```
Create storage disk
```
dd if=/dev/zero of=disk.img bs=1M count=1024
```
### Run qemu
```
# static hostid need for zfs
qemu-system-x86_64 \
	-cpu host -enable-kvm -smp 1,cores=1 -m 1024M -nographic \
	-netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::4445-:445 \
	-device virtio-net-pci,netdev=net0 \
	-drive file=disk.img,format=raw,if=virtio \
	-kernel vmlinuz-6.18.58-0-virt-x86_64 -initrd my-custom-initrd \
	-append "console=ttyS0 spl.spl_hostid=0xa9b23268 admin_passwd=super smb_passwd=share"
```
After starting linux you need create zfs pool and storage, login to admin user in qemu console and run next command.
```
sudo zpool create \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  -O mountpoint=/data \
  data /dev/vda

sudo zfs create \
  -o dedup=blake3 \
  -o xattr=sa \
  -o atime=off \
  data/share

chown admin:admin -R /data/share

sudo poweroff
```

Restart qemu machine and make sure that ssh and samba are accessible.
