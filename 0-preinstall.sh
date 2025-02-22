#!/usr/bin/env bash
#-------------------------------------------------------------------------
#      _          _    __  __      _   _
#     /_\  _ _ __| |_ |  \/  |__ _| |_(_)__
#    / _ \| '_/ _| ' \| |\/| / _` |  _| / _|
#   /_/ \_\_| \__|_||_|_|  |_\__,_|\__|_\__|
#  Arch Linux Post Install Setup and Config
#-------------------------------------------------------------------------


#SET UP MIRRORS
echo "-------------------------------------------------"
echo "Setting up mirrors for optimal download          "
echo "-------------------------------------------------"

#Look up country iso-code with ifconfig.co and set as variable iso
iso=$(curl -4 ifconfig.co/country-iso)

#Activate network time synchronisation
timedatectl set-ntp true

#Install pacman-contrib and terminus-font
pacman -S --noconfirm pacman-contrib terminus-font

#Set font to ter-v22b
setfont ter-v22b

#Install reflector rsync
pacman -S --noconfirm reflector rsync

#create a backup of the mirrorlist
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

#update mirror list with fastest mirrors
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist


#MAKE MOUNT DIRECTORY
mkdir /mnt


#FORMAT DISK
#Install disk partitioning utilities
echo -e "\nInstalling prereqs...\n$HR"
pacman -S --noconfirm --needed gptfdisk btrfs-progs

#List the disk partition table
echo "-------------------------------------------------"
echo "-------select your disk to format----------------"
echo "-------------------------------------------------"
lsblk

#Prompt user to select disk to be partitioned and set as variable DISK
echo "Please enter disk to work on: (example /dev/sda)"
read DISK

#Seek confirmation to format disk and store as variable formatdisk
echo "THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK"
read -p "are you sure you want to continue (Y/N):" formatdisk

#If $formatdisk is yes then run disc format commands
case $formatdisk in
y|Y|yes|Yes|YES)
echo "--------------------------------------"
echo -e "\nFormatting disk...\n$HR"
echo "--------------------------------------"

# disk prep
sgdisk -Z ${DISK} # zap all on disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+1000M ${DISK} # partition 1 (UEFI SYS), default start block, 512MB
sgdisk -n 2:0:0     ${DISK} # partition 2 (Root), default start, remaining

# set partition types
sgdisk -t 1:ef00 ${DISK}
sgdisk -t 2:8300 ${DISK}

# label partitions
sgdisk -c 1:"UEFISYS" ${DISK}
sgdisk -c 2:"ROOT" ${DISK}

# make filesystems
echo -e "\nCreating Filesystems...\n$HR"

mkfs.vfat -F32 -n "UEFISYS" "${DISK}1"
mkfs.btrfs -L "ROOT" "${DISK}2"
mount -t btrfs "${DISK}2" /mnt
btrfs subvolume create /mnt/@
umount /mnt
;;
esac

# mount target
mount -t btrfs -o subvol=@ "${DISK}2" /mnt
mkdir /mnt/boot
mkdir /mnt/boot/efi
mount -t vfat "${DISK}1" /mnt/boot/

echo "--------------------------------------"
echo "-- Arch Install on Main Drive       --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-firmware vim nano sudo archlinux-keyring wget libnewt --noconfirm --needed
genfstab -U /mnt >> /mnt/etc/fstab
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
echo "--------------------------------------"
echo "-- Bootloader Systemd Installation  --"
echo "--------------------------------------"
bootctl install --esp-path=/mnt/boot
[ ! -d "/mnt/boot/loader/entries" ] && mkdir -p /mnt/boot/loader/entries
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux  
linux /vmlinuz-linux  
initrd  /initramfs-linux.img  
options root=${DISK}2 rw rootflags=subvol=@
EOF
cp -R ~/ArchMatic /mnt/root/
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
echo "--------------------------------------"
echo "--   SYSTEM READY FOR 0-setup       --"
echo "--------------------------------------"
