#!/bin/sh

# Function for extracting source packages
extract()
{
	if [ -d $CURRENT ]
	then
		echo "$CURRENT exists"
	else
		echo "Extracting $CURRENT.tar.bz2"
		tar -jxf $CURRENT.tar.bz2
	fi
	return
}

TOPLEVELDIR=`pwd`
TARGET=arm-unknown-linux-uclibc
ARCH=arm
PREFIX=$TOPLEVELDIR/cortex
CURRENT=

GCC=gcc-4.4.0
BINUTILS=binutils-2.19.1
KERNEL=linux-2.6.30
GMP=gmp-4.3.1
MPFR=mpfr-2.4.1

if [ $1 = "clean" ]
then
	rm -rf $GCC $BINUTILS $KERNEL $GMP $MPFR $PREFIX build
	return
fi

# Download source packages
wget -c http://ftp.gnu.org/gnu/gcc/$GCC/$GCC.tar.bz2 \
		http://ftp.gnu.org/gnu/binutils/$BINUTILS.tar.bz2 \
		http://ftp.gnu.org/gnu/gmp/$GMP.tar.bz2 \
		http://www.mpfr.org/mpfr-current/$MPFR.tar.bz2 \
		http://www.kernel.org/pub/linux/kernel/v2.6/$KERNEL.tar.bz2 \
		http://svn.cross-lfs.org/svn/repos/cross-lfs/branches/clfs-embedded/patches/binutils-2.19.1-branch_update-1.patch \
		http://svn.cross-lfs.org/svn/repos/cross-lfs/branches/clfs-embedded/patches/binutils-2.19.1-posix-1.patch

mkdir -pv build/$BINUTILS
mkdir -pv build/$GCC
mkdir -pv $PREFIX

# Extract Linux kernel
CURRENT=$KERNEL
echo "$CURRENT"
extract

# Installation of Linux Headers
mkdir -pv $PREFIX/usr/include
cd $KERNEL
make mrproper
make ARCH=$ARCH headers_check
make ARCH=$ARCH INSTALL_HDR_PATH=tmp_dest headers_install
cp -rv tmp_dest/include/* $PREFIX/usr/include
rm -rf tmp_dest
cd $TOPLEVELDIR

# Extract build and install GMP
CURRENT=$GMP
extract
cd $GMP
./configure --prefix=$PREFIX --enable-mpbsd
make
make install
cd $TOPLEVELDIR

# Extract build and install MPFR
CURRENT=$MPFR
extract
cd $MPFR
LDFLAGS="-Wl,-rpath,$PREFIX/lib" ./configure --prefix=$PREFIX \
	--enable-shared --with-gmp=$PREFIX
make
make install
cd $TOPLEVELDIR

# Extract binutils
CURRENT=$BINUTILS
extract

# Apply binutils patches
cd $BINUTILS
patch -Np1 -i ../binutils-2.19.1-branch_update-1.patch
patch -Np1 -i ../binutils-2.19.1-posix-1.patch

# Fix for BUG 7026
# http://sourceware.org/bugzilla/show_bug.cgi?id=7026
sed -i 's/as_bad (_(r/as_bad ("%s", _(r/' $BINUTILS/gas/config/tc-arm.c

# Build and install binutils
cd $TOPLEVELDIR/build/$BINUTILS
if [ -f Makefile ]
then
	echo "Using old configuration. Delete build/$BINUTILS/Makefile to configure again"
else
	$TOPLEVELDIR/$BINUTILS/configure --target=$TARGET --prefix=$PREFIX \
	--with-sysroot=$PREFIX --disable-nls --enable-shared --disable-multilib
fi
make configure-host
make
make install
cp -v $TOPLEVELDIR/$BINUTILS/include/libiberty.h $PREFIX/usr/include
cd $TOPLEVELDIR

# Extract and Build Cross GCC with static libgcc and no threads

# Extract GCC
CURRENT=$GCC
extract

# Build and install GCC
cd build/$GCC
if [ -f Makefile ]
then
	echo "Using old configuration. Delete build/$BINUTILS/Makefile to configure again"
else
	AR=ar LDFLAGS="-Wl,-rpath,$PREFIX/lib" \
	$TOPLEVELDIR/$GCC/configure --target=$TARGET --build=$MACHTYPE \
	--prefix=$PREFIX --host=$MACHTYPE --target=$TARGET \
	--with-sysroot=$PREFIX --disable-nls --disable-shared \
	--with-mpfr=$PREFIX --with-gmp=$PREFIX --without-headers \
	--with-newlib --disable-decimal-float --disable-libgomp \
	--disable-libmudflap --disable-libssp --disable-threads --enable-languages=c
fi
make
make install
cd $TOPLEVELDIR

