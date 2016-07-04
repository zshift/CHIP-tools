#!/bin/sh

INPUTDIR="$1"
OUTPUTDIR="$2"

# build the UBI image
prepare_ubi() {
  local tmpdir=`mktemp -d -t chip-ubi-XXXXXX`
  local rootfs=$tmpdir/rootfs
  local ubifs=$tmpdir/rootfs.ubifs
  local ubicfg=$tmpdir/ubi.cfg
  local outputdir="$1"
  local rootfstar="$2"
  local nandtype="$3"
  local maxlebcount="$4"
  local eraseblocksize="$5"
  local pagesize="$6"
  local subpagesize="$7"
  local ubi=$outputdir/chip-$eraseblocksize-$pagesize.ubi

  if [ -z $subpagesize ]; then
    subpagesize=$pagesize
  fi

  if [ "$nandtype" = "mlc" ]; then
    lebsize=$((eraseblocksize/2-$pagesize*2))
  elif [ $subpagesize -lt $pagesize ]; then
    lebsize=$((eraseblocksize-pagesize))
  else
    lebsize=$((eraseblocksize-pagesize*2))
  fi

  mkdir -p $rootfs
  tar -xf $rootfstar -C $rootfs
  mkfs.ubifs -d $rootfs -m $pagesize -e $lebsize -c $maxlebcount -o $ubifs
  echo "[rootfs]
mode=ubi
vol_id=0
vol_type=dynamic
vol_name=rootfs
vol_alignment=1
vol_flags=autoresize
image=$ubifs" > $ubicfg

  ubinize -o $ubi -p $eraseblocksize -m $pagesize -s $subpagesize $ubicfg
  rm -rf $tmpdir
}

# build the SPL image
prepare_spl() {
  local tmpdir=`mktemp -d -t chip-spl-XXXXXX`
  local outputdir=$1
  local spl=$2
  local eraseblocksize=$3
  local pagesize=$4
  local oobsize=$5
  local repeat=$((eraseblocksize/pagesize/64))
  local nandspl=$tmpdir/nand-spl.bin
  local nandpaddedspl=$tmpdir/nand-padded-spl.bin
  local nandrepeatedspl=$outputdir/spl-$eraseblocksize-$pagesize-$oobsize.bin
  local padding=$tmpdir/padding
  local splpadding=$tmpdir/nand-spl-padding

  sunxi-nand-image-builder -c 64/1024 -p $pagesize -o $oobsize -u 1024 -e $eraseblocksize -b $spl $nandspl

  local i=0
  while [ $i -lt $repeat ]; do
    local paddingstart=$((pagesize*24+$i*$pagesize*64))

    dd if=/dev/urandom of=$padding bs=$pagesize count=40
    sunxi-nand-image-builder -c 64/1024 -p $pagesize -o $oobsize -u 1024 -e $eraseblocksize -b $padding $splpadding
    cat $nandspl $splpadding > $nandpaddedspl

    if [ "$i" -eq "0" ]; then
      cat $nandpaddedspl > $nandrepeatedspl
    else
      cat $nandpaddedspl >> $nandrepeatedspl
    fi

    i=$((i+1))
  done

  rm -rf $tmpdir
}

# build the bootloader image
prepare_uboot() {
  local outputdir=$1
  local uboot=$2
  local eraseblocksize=$3
  local paddeduboot=$outputdir/uboot-$eraseblocksize.bin

  dd if=$uboot of=$paddeduboot bs=$eraseblocksize conv=sync
}

## prepare ubi images ##
# Toshiba SLC image:
# not supported yet, because MLC aware ubinize does not support building
# SLC images.
# prepare_ubi $OUTPUTDIR $INPUTDIR/rootfs.tar "slc" 2048 262144 4096 1024
# Toshiba/Hynix MLC image:
prepare_ubi $OUTPUTDIR $INPUTDIR/rootfs.tar "mlc" 4096 4194304 16384 16384

## prepare spl images ##
# Toshiba SLC image:
prepare_spl $OUTPUTDIR $INPUTDIR/sunxi-spl.bin 262144 4096 256
# Toshiba MLC image:
prepare_spl $OUTPUTDIR $INPUTDIR/sunxi-spl.bin 4194304 16384 1280
# Hynix MLC image:
prepare_spl $OUTPUTDIR $INPUTDIR/sunxi-spl.bin 4194304 16384 1664

## prepare uboot images ##
# Toshiba SLC image:
prepare_uboot $OUTPUTDIR $INPUTDIR/u-boot-dtb.bin 262144
# Toshiba/Hynix MLC image:
prepare_uboot $OUTPUTDIR $INPUTDIR/u-boot-dtb.bin 4194304
