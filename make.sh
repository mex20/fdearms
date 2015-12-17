export TARGET_DEV=/dev/sdc   
export TARGET_MNT=/mnt       
export WORKING_DIR=./working
mkdir $WORKING_DIR
cd $WORKING_DIR
sudo parted $TARGET_DEV --script mklabel msdos
sudo parted $TARGET_DEV --script mkpart primary ext4 5M 128M # boot
sudo parted $TARGET_DEV --script mkpart primary ext4 128M 100% # root */for 32gb sdcard */
sudo mkfs.ext4 ${TARGET_DEV}1
sudo cryptsetup -v --cipher aes-xts-plain64 --key-size 512 --hash sha256 --iter-time 2000 --use-urandom --verify-passphrase luksFormat ${TARGET_DEV}2
sudo cryptsetup luksOpen ${TARGET_DEV}2 root
sudo mkfs.ext4 /dev/mapper/root
sudo mkdir $TARGET_MNT/boot
sudo mount ${TARGET_DEV}1 $TARGET_MNT/boot


wget http://cdimage.ubuntu.com/ubuntu-core/releases/14.04/release/ubuntu-core-14.04.2-core-armhf.tar.gz

sudo tar xvf ubuntu-core-14.04.2-core-armhf.tar.gz -C $TARGET_MNT
sudo wget https://raw.githubusercontent.com/inversepath/usbarmory/master/software/ubuntu_conf/ttymxc0.conf -O ${TARGET_MNT}/etc/init/ttymxc0.conf
sudo cp /usr/bin/qemu-arm-static ${TARGET_MNT}/usr/bin/qemu-arm-static
echo "nameserver 8.8.8.8" | sudo tee ${TARGET_MNT}/etc/resolv.conf
sudo sed -i 's/^# deb/deb/' ${TARGET_MNT}/etc/apt/sources.list
echo -e "${TARGET_DEV}1    /boot    ext4    defaults 0    2" | sudo tee -a ${TARGET_MNT}/etc/fstab
echo -e "/dev/mapper/root    /   ext4    errors=remount-ro,discard 0       1" | sudo tee -a ${TARGET_MNT}/etc/fstab
echo -e "root ${TARGET_DEV}2 none luks,discard" | sudo tee -a ${TARGET_MNT}/etc/crypttab
sudo chroot $TARGET_MNT apt-get update
sudo chroot $TARGET_MNT apt-get install -y openssh-server whois fake-hwclock

echo "ledtrig_heartbeat" | sudo tee -a ${TARGET_MNT}/etc/modules
echo "ci_hdrc_imx" | sudo tee -a ${TARGET_MNT}/etc/modules
echo "g_ether" | sudo tee -a ${TARGET_MNT}/etc/modules
echo "options g_ether use_eem=0 dev_addr=1a:55:89:a2:69:41 host_addr=1a:55:89:a2:69:42" | sudo tee -a ${TARGET_MNT}/etc/modprobe.d/usbarmory.conf
echo -e 'auto usb0\nallow-hotplug usb0\niface usb0 inet static\n  address 10.0.0.1\n  netmask 255.255.255.0\n  gateway 10.0.0.2'| sudo tee -a ${TARGET_MNT}/etc/network/interfaces
echo "t4.aratech.ouri" | sudo tee ${TARGET_MNT}/etc/hostname
echo "gotogr  ALL=(ALL) NOPASSWD: ALL" | sudo tee -a ${TARGET_MNT}/etc/sudoers
echo -e "127.0.1.1\tt4.aratech.ouri" | sudo tee -a ${TARGET_MNT}/etc/hosts
sudo chroot $TARGET_MNT /usr/sbin/useradd -s /bin/bash -m gotogr
sudo chroot $TARGET_MNT /usr/sbin/useradd -D -s /bin/bash t4ip
sudo mkdir ${TARGET_MNT}/root/.ssh
sudo chmod 700 ${TARGET_MNT}/root/.ssh
sudo mkdir /fdearms/finset/
sudo mkdir /fdearms/finset/securesh/
sudo mkdir /fdearms/finset/securesh/keys
cd /fdearms/finset/securesh/keys
touch /fdearms/finset/securesh/keys/authorized_keys
ssh-keygen -t rsa -N '' -C g0t0gr -f goto.rsa
ssh-keygen -t rsa -N '' -C t4ip -f t4ip.rsa
cat goto.rsa.pub >> /authorized_keys
cat t4ip.rsa.pub >> /authorized_keys
sudo cp -v './authorized_keys'  '$TARGET_MNT/root/.ssh/authorized_keys'
sudo chmod 600 ${TARGET_MNT}/root/.ssh/authorized_keys
cd /fdearms
 

export ARCH=arm
wget https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.3.tar.xz
tar xvf linux-4.3.tar.xz && cd linux-4.3
wget https://raw.githubusercontent.com/inversepath/usbarmory/master/software/kernel_conf/usbarmory_linux-4.3.config -O .config
wget https://raw.githubusercontent.com/inversepath/usbarmory/master/software/kernel_conf/imx53-usbarmory-common.dtsi -O arch/arm/boot/dts/imx53-usbarmory-common.dtsi
wget https://raw.githubusercontent.com/inversepath/usbarmory/master/software/kernel_conf/imx53-usbarmory.dts -O arch/arm/boot/dts/imx53-usbarmory.dts
make uImage LOADADDR=0x70008000 modules imx53-usbarmory.dtb
sudo cp arch/arm/boot/uImage ${TARGET_MNT}/boot/
sudo cp arch/arm/boot/dts/imx53-usbarmory.dtb ${TARGET_MNT}/boot/imx53-usbarmory.dtb
sudo make INSTALL_MOD_PATH=$TARGET_MNT ARCH=arm modules_install














wget ftp://ftp.denx.de/pub/u-boot/u-boot-2015.10.tar.bz2
tar xvf u-boot-2015.10.tar.bz2 && cd u-boot-2015.10
echo -e "CONFIG_FIT=y\nCONFIG_FIT_VERBOSE=y\nCONFIG_FIT_SIGNATURE=y\nCONFIG_DM=y\nCONFIG_RSA=y\nCONFIG_OF_CONTROL=y\nCONFIG_OF_SEPARATE=y\n" >> configs/usbarmory_defconfig
sed -i 's@setenv bootargs console=${console} ${bootargs_default};@setenv bootargs console=ttyGS0,115200 console=${console} ip=10.0.0.1::10.0.0.2:255.255.255.0::usb0:none cryptdevice=/dev/mmcblk0p2:root root=/dev/mapper/root rw rootwait;@' include/configs/usbarmory.h
sed -i 's@ext2load mmc 0:1 ${kernel_addr_r} /boot/uImage;@if load ${devtype} ${devnum}:${bootpart} 0x80000000 /uImage; then@' include/configs/usbarmory.h
sed -i 's@ext2load mmc 0:1 ${fdt_addr_r} /boot/${fdtfile};@     bootm 0x80000000;@' include/configs/usbarmory.h
sed -i 's@bootm ${kernel_addr_r} - ${fdt_addr_r}@fi@' include/configs/usbarmory.h

make distclean
make usbarmory_config
make ARCH=arm tools





cd $WORKING_DIR
cp linux-4.3/arch/arm/boot/zImage . #FIXME PATH
cp linux-4.3/arch/arm/boot/dts/imx53-usbarmory.dtb
sudo cp ${TARGET_MNT}/boot/initrd.img-4.3.0 .
openssl genrsa -F4 -out yuhuang.key 2048
openssl req -batch -new -x509 -key yuhuang.key -out yuhuang.crt


cat <<EOF >uboot.dts
/dts-v1/;

/ {
   model = "Keys";
   compatible = "inversepath,imx53-usbarmory", "fsl,imx53";

   signature {
       key-ubootfit {
           required = "conf";
           algo = "sha256,rsa2048";
           key-name-hint = "yuhuang";
       };
   };
};
EOF

dtc -p 0x1000 uboot.dts -O dtb -o uboot.dtb






cat <<EOF >image.its
/dts-v1/;

/ {
   description = "USB Armory Kernel";
   #address-cells = <1>;

   images {
       kernel@1 {
           description = "kernel";
           data = /incbin/("./zImage");
           type = "kernel";
           arch = "arm";
           os = "linux";
           compression = "none";
           load = <0x70800000>;
           entry = <0x70800000>;
           hash@1 {
               algo = "sha256";
           };
       };

       ramdisk@1 {
           description = "initramfs";
           data = /incbin/("./initrd.img-4.3.0");
           type = "ramdisk";
           arch = "arm";
           os = "linux";
           compression = "gzip";
           load = <0x73000000>;
           entry = <0x73000000>;
           hash@1 {
               algo = "sha256";
           };
       };

       fdt@1 {
           description = "imx53-usbarmory.dtb";
           data = /incbin/("./imx53-usbarmory.dtb");
           type = "flat_dt";
           arch = "arm";
           compression = "none";
           load = <0x71000000>;
           entry = <0x71000000>;
           hash@1 {
               algo = "sha256";
           };
       };
   };

   configurations {
       default = "config@1";

       config@1 {
           description = "default";
           kernel = "kernel@1";
           ramdisk = "ramdisk@1";
           fdt = "fdt@1";
           signature@1 {
               algo = "sha256,rsa2048";
               key-name-hint = "yuhuang";
               sign-images = "kernel", "ramdisk", "fdt";
           };
       };
   };
};
EOF
$WORKING_DIR/u-boot-2015.10/tools/mkimage -D "-I dts -O dtb -p 2000" -f image.its uImage



