#!/bin/bash
#
# Colors for error/info messages
#
TXTRED='\e[0;31m' 		# Red
TXTGRN='\e[0;32m' 		# Green
TXTYLW='\e[0;33m' 		# Yellow
BLDRED='\e[1;31m' 		# Red-Bold
BLDGRN='\e[1;32m' 		# Green-Bold
BLDYLW='\e[1;33m' 		# Yellow-Bold
TXTCLR='\e[0m'    		# Text Reset
#
# Directory Settings
#
export KERNELDIR=`readlink -f .`
export TOOLBIN="${KERNELDIR}/../bin"
export INITRAMFS_SOURCE="${KERNELDIR}/../initramfs"
export INITRAMFS_TMP="/tmp/initramfs-gti9210t"
export RELEASEDIR="${KERNELDIR}/../releases"

# BuildHostname
export KBUILD_BUILD_HOST=`hostname | sed 's|ip-projects.de|dream-irc.com|g'`

#
# Version of this Build
#
KRNRLS="DreamKernel-GTI9210T-v1.0BETA"


#
# Target Settings
#
export ARCH=arm
# export CROSS_COMPILE=$WORK_DIR/../cyano-dream/system/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-
export CROSS_COMPILE=/home/talustus/arm-gti9210t-androideabi/bin/galaxys2-
export USE_SEC_FIPS_MODE=true

if [ "${1}" != "" ];
then
  if [ -d  $1 ];
  then
    export KERNELDIR=`readlink -f ${1}`
    echo -e "${TXTGRN}Using alternative Kernel Directory: ${KERNELDIR}${TXTCLR}"
  else
    echo -e "${BLDRED}Error: ${1} is not a directory !${TXTCLR}"
    echo -e "${BLDRED}Nothing todo, Exiting ... !${TXTCLR}"
    exit 1
  fi
fi

if [ ! -f $KERNELDIR/.config ];
then
  echo -e "${TXTYLW}Kernel config does not exists, creating default config (dream_gti9210t_defconfig):${TXTCLR}"
  make ARCH=arm dream_gti9210t_defconfig
  # make -C $KERNELDIR cyanogenmod_hercules_defconfig
  echo -e "${TXTYLW}Kernel config created .. redo the command: $0:${TXTCLR}"
  exit 0
fi

. $KERNELDIR/.config

# remove Files of old/previous Builds
#
echo -e "${TXTYLW}Deleting Files of previous Builds ...${TXTCLR}"
make -j10 clean

# Remove Old initramfs
echo -e "${TXTYLW}Deleting old InitRAMFS${TXTCLR}"
rm -rvf $INITRAMFS_TMP
rm -vf $INITRAMFS_TMP.*

# Clean Up old Buildlogs
echo -e "${TXTYLW}Deleting old logfiles${TXTCLR}"
rm -v $KERNELDIR/compile-modules.log
rm -v $KERNELDIR/compile-zImage.log

# Remove previous Kernelfiles
echo -e "${TXTYLW}Deleting old Kernelfiles${TXTCLR}"
rm -v $KERNELDIR/arch/arm/boot/kernel
rm -v $KERNELDIR/arch/arm/boot/zImage
rm -v $KERNELDIR/boot.img


# Start the Build
#
echo -e "${TXTYLW}CleanUP done, starting kernel Build ...${TXTCLR}"

nice -n 10 make -j12 modules 2>&1 | tee compile-modules.log || exit 1
# nice -n 10 make -j12 KBUILD_BUILD_HOST="$KBUILD_BUILD_HOST" modules 2>&1 | tee compile-modules.log || exit 1
#
echo -e "${TXTYLW}Modules Build done ...${TXTCLR}"
sleep 2

echo -e "${TXTGRN}Build: Stage 1 successfully completed${TXTCLR}"

# copy initramfs files to tmp directory
#
echo -e "${TXTGRN}Copying initramfs Filesystem to: ${INITRAMFS_TMP}${TXTCLR}"
cp -vax $INITRAMFS_SOURCE $INITRAMFS_TMP
sleep 1

# remove repository realated files
#
echo -e "${TXTGRN}Deleting Repository related Files (.git, .hg etc)${TXTCLR}"
find $INITRAMFS_TMP -name .git -exec rm -rvf {} \;
find $INITRAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rvf {} \;
rm -rvf $INITRAMFS_TMP/.hg

# copy modules into initramfs
#
echo -e "${TXTGRN}Copying Modules to initramfs: ${INITRAMFS_TMP}/lib/modules${TXTCLR}"

mkdir -pv $INITRAMFS_TMP/lib/modules
find $KERNELDIR -name '*.ko' -exec cp -av {} $INITRAMFS_TMP/lib/modules/ \;
sleep 1

echo -e "${TXTGRN}Striping Modules to save space${TXTCLR}"
${CROSS_COMPILE}strip --strip-unneeded $INITRAMFS_TMP/lib/modules/*
sleep 1

# create the initramfs cpio archive
#
$TOOLBIN/mkbootfs $INITRAMFS_TMP > $INITRAMFS_TMP.cpio
echo -e "${TXTGRN}Unpacked Initramfs: $(ls -lh $INITRAMFS_TMP.cpio)${TXTCLR}"

# Create gziped initramfs
#
echo -e "${TXTGRN}compressing InitRamfs...${TXTCLR}"
$TOOLBIN/minigzip < $INITRAMFS_TMP.cpio > $INITRAMFS_TMP.img
echo -e "${TXTGRN}Final gzip compressed Initramfs: $(ls -lh $INITRAMFS_TMP.img)${TXTCLR}"

### 2nd way of ramfs creation
#cd $INITRAMFS_TMP
#find | fakeroot cpio -H newc -o > $INITRAMFS_TMP.cpio 2>/dev/null
#echo -e "${TXTGRN}Unpacked Initramfs: $(ls -lh $INITRAMFS_TMP.cpio)${TXTCLR}"
#echo -e "${TXTGRN}compressing InitRamfs...${TXTCLR}"
#gzip -9 $INITRAMFS_TMP.cpio
#echo -e "${TXTGRN}Packed Initramfs: $(ls -lh $INITRAMFS_TMP.img)${TXTCLR}"
sleep 1

#cd -

# Start Final Kernel Build
#
echo -e "${TXTYLW}Starting final Build: Stage 2${TXTCLR}"
nice -n 10 make -j10 zImage 2>&1 | tee compile-zImage.log || exit 1
sleep 1
cp -v $KERNELDIR/arch/arm/boot/zImage $KERNELDIR/arch/arm/boot/kernel

echo " "
echo -e "${TXTGRN}Final Build: Stage 3. Creating bootimage !${TXTCLR}"
echo " "

$TOOLBIN/mkbootimg --kernel $KERNELDIR/arch/arm/boot/kernel --ramdisk $INITRAMFS_TMP.img --cmdline "androidboot.hardware=qcom msm_watchdog.appsbark=0 msm_watchdog.enable=1" --base 0x40400000 --pagesize 2048 --ramdiskaddr 0x41800000 --output $KERNELDIR/boot.img
# $TOOLBIN/mkbootimg --kernel $KERNELOUT/arch/arm/boot/kernel --ramdisk $WORK_DIR/ramdisk.img --cmdline "androidboot.hardware=qcom msm_watchdog.appsbark=0 msm_watchdog.enable=1" --base 0x40400000 --pagesize 2048 --ramdiskaddr 0x41800000 --output $KERNELOUT/boot.img
rm -v $KERNELDIR/arch/arm/boot/kernel
echo " "
echo -e "${TXTGRN}Final Build: Stage 3 completed successfully!${TXTCLR}"
echo " "

# Create ODIN Flashable TAR archiv
#
ARCNAME="$KRNRLS-`date +%Y%m%d%H%M%S`"

echo -e "${BLDRED}creating ODIN-Flashable TARand CWM Zip ${ARCNAME}${TXTCLR}"
cd $KERNELDIR
tar cfv $RELEASEDIR/$ARCNAME.tar boot.img

## CWM
cp -v $RELEASEDIR/updater-template.zip $RELEASEDIR/$ARCNAME-CWM.zip
zip -u $RELEASEDIR/$ARCNAME-CWM.zip boot.img

echo "  "
ls -lh $RELEASEDIR/$ARCNAME.tar
ls -lh $RELEASEDIR/$ARCNAME-CWM.zip
cd -

echo -e "${BLDGRN}	#############################	${TXTCLR}"
echo -e "${TXTRED}	# Script completed, exiting #	${TXTCLR}"
echo -e "${BLDGRN}	#############################	${TXTCLR}"
