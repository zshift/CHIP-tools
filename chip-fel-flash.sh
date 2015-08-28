#!/bin/bash

echo "BUILDROOT_OUTPUT_DIR = $BUILDROOT_OUTPUT_DIR"

NAND_ERASE_BB=false
if [ "$1" == "erase-bb" ]; then
	NAND_ERASE_BB=true
fi

PATH=$PATH:$BUILDROOT_OUTPUT_DIR/host/usr/bin
TMPDIR=`mktemp -d`
PADDED_SPL="$TMPDIR/sunxi-padded-spl"
PADDED_SPL_SIZE=0
UBOOT_ENV="$BUILDROOT_OUTPUT_DIR/images/uboot-env.bin"
UBOOT_SCRIPT="$TMPDIR/uboot.scr"
UBOOT_SCRIPT_MEM_ADDR=0x43100000
UBOOT_SCRIPT_SRC="$TMPDIR/uboot.cmds"
SPL="$BUILDROOT_OUTPUT_DIR/images/sunxi-spl.bin"
SPL_MEM_ADDR=0x43000000
UBOOT="$BUILDROOT_OUTPUT_DIR/images/u-boot-dtb.bin"
PADDED_UBOOT="$TMPDIR/padded-uboot"
PADDED_UBOOT_SIZE=0
UBOOT_MEM_ADDR=0x4a000000
UBI="$BUILDROOT_OUTPUT_DIR/images/rootfs.ubi"
UBI_SIZE=`stat --printf="%s" $UBI | xargs printf "0x%08x"`

prepare_images() {
	local in=$SPL
	local out=$PADDED_SPL

	if [ -e $out ]; then
		rm $out
	fi

	# The BROM cannot read 16K pages: it only reads 8k of data at most.
	# Split the SPL image in 8k chunks and pad each chunk with 8k of random
	# data to limit the impact of repeated patterns on the MLC chip.

	dd if=$in of=$out bs=8k count=1 skip=0 conv=sync
	dd if=/dev/urandom of=$out bs=8k count=1 seek=1 conv=sync
	dd if=$in of=$out bs=8k count=1 skip=1 seek=2 conv=sync
	dd if=/dev/urandom of=$out bs=8k count=1 seek=3 conv=sync
	dd if=$in of=$out bs=8k count=1 skip=2 seek=4 conv=sync
	dd if=/dev/urandom of=$out bs=8k count=1 seek=5 conv=sync
	PADDED_SPL_SIZE=`stat --printf="%s" $out | xargs printf "0x%08x"`

	# Align the u-boot image on a page boundary
	dd if=$UBOOT of=$PADDED_UBOOT bs=16k conv=sync
	PADDED_UBOOT_SIZE=`stat --printf="%s" $PADDED_UBOOT | xargs printf "0x%08x"`
}

prepare_uboot_script() {
	if [ "$NAND_ERASE_BB" = true ] ; then
		echo "nand scrub -y 0x0 0x200000000" > $UBOOT_SCRIPT_SRC
	fi

	echo "fastboot" >> $UBOOT_SCRIPT_SRC

	mkimage -A arm -T script -C none -n "flash CHIP" -d $UBOOT_SCRIPT_SRC $UBOOT_SCRIPT
}

echo == Preparing images ==
prepare_images
prepare_uboot_script

echo == Uploading the SPL to SRAM and executing it ==
fel spl $SPL

sleep 1 # wait for DRAM initialization to complete

echo == Uploading U-Boot to RAM ==
fel write $UBOOT_MEM_ADDR $PADDED_UBOOT
fel write $UBOOT_SCRIPT_MEM_ADDR $UBOOT_SCRIPT

echo == Executing the main u-boot binary ==
fel exe $UBOOT_MEM_ADDR

echo == Writing images ==
fastboot flash spl $PADDED_SPL
fastboot flash spl-backup $PADDED_SPL
fastboot flash uboot $PADDED_UBOOT
fastboot flash env $UBOOT_ENV
fastboot flash UBI $UBI

echo == Flashing done. Resetting. ==
fastboot reboot

rm -rf $TMPDIR
