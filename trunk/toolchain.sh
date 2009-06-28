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
KERNEL=linux-2.6.29
GMP=gmp-4.3.1
MPFR=mpfr-2.4.1
LIBC=uClibc-0.9.30.1

# Set PATH
export PATH=$PREFIX/bin:$PATH

if [ $# -eq 1 ] && [ $1 = "clean" ]
then
	echo "Cleaning..."
	rm -rf $GCC $BINUTILS $KERNEL $GMP $MPFR $LIBC $PREFIX build
	return
else
	echo "Running build script..."
fi

SVN_CLFS=svn.cross-lfs.org/svn/repos/cross-lfs/branches/clfs-embedded

# Download source packages
wget -c http://ftp.gnu.org/gnu/gcc/$GCC/$GCC.tar.bz2 \
		http://ftp.gnu.org/gnu/binutils/$BINUTILS.tar.bz2 \
		http://ftp.gnu.org/gnu/gmp/$GMP.tar.bz2 \
		http://www.mpfr.org/mpfr-current/$MPFR.tar.bz2 \
		http://www.kernel.org/pub/linux/kernel/v2.6/$KERNEL.tar.bz2 \
		http://uclibc.org/downloads/$LIBC.tar.bz2 \
		http://$SVN_CLFS/patches/uClibc-0.9.30.1-branch_update-1.patch \
		http://$SVN_CLFS/config/uClibc-0.9.30.1.config \
		http://$SVN_CLFS/patches/binutils-2.19.1-branch_update-1.patch \
		http://$SVN_CLFS/patches/binutils-2.19.1-posix-1.patch

mkdir -pv build/$BINUTILS
mkdir -pv build/$GCC
mkdir -pv $PREFIX

# Extract Linux kernel
CURRENT=$KERNEL
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
if [ -f Makefile ]
then
	echo "Skipping $GMP build. Remove $GMP/Makefile to build again."
else
	./configure --prefix=$PREFIX --enable-mpbsd
	make
	make install
fi
cd $TOPLEVELDIR

# Extract build and install MPFR
CURRENT=$MPFR
extract
cd $MPFR
if [ -f Makefile ]
then
	echo "Skipping $MPFR build. Remove $MPFR/Makefile to build again"
else
	LDFLAGS="-Wl,-rpath,$PREFIX/lib" ./configure --prefix=$PREFIX \
		--enable-shared --with-gmp=$PREFIX
	make
	make install
fi
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
sed -i 's/as_bad (_(r/as_bad ("%s", _(r/' gas/config/tc-arm.c

# Build and install binutils
cd $TOPLEVELDIR/build/$BINUTILS
if [ -f Makefile ]
then
	echo "Skipping $BINUTILS build. Delete build/$BINUTILS/Makefile to build again"
else
	$TOPLEVELDIR/$BINUTILS/configure --target=$TARGET --prefix=$PREFIX \
	--with-sysroot=$PREFIX --disable-nls --enable-shared --disable-multilib

	make configure-host
	make
	make install
fi
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
	echo "Skipping $GCC build. Delete build/$GCC/Makefile to build again"
else
	AR=ar LDFLAGS="-Wl,-rpath,$PREFIX/lib" \
	$TOPLEVELDIR/$GCC/configure --target=$TARGET --build=$MACHTYPE \
	--prefix=$PREFIX --host=$MACHTYPE --target=$TARGET \
	--with-sysroot=$PREFIX --disable-nls --disable-shared \
	--with-mpfr=$PREFIX --with-gmp=$PREFIX --without-headers \
	--with-newlib --disable-decimal-float --disable-libgomp \
	--disable-libmudflap --disable-libssp --disable-threads --enable-languages=c

	make
	make install
fi
cd $TOPLEVELDIR

# Extract build and install uClibc
CURRENT=$LIBC
extract
cd $LIBC
patch -Np1 -i ../uClibc-0.9.30.1-branch_update-1.patch
cp ../uClibc-0.9.30.1.config .config
make menuconfig
make
make PREFIX=$PREFIX install
cd $TOPLEVELDIR

# Installation of Final GCC cross compiler
cd build/$GCC
rm -rf *
$TOPLEVELDIR/$GCC/configure --prefix=$PREFIX --build=$MACHTYPE \
	--target=$TARGET --host=$MACHTYPE --with-sysroot=$PREFIX \
	--disable-nls --enable-shared --enable-languages=c --enable-c99 \
	--enable-long-long --with-mpfr=$PREFIX --with-gmp=$PREFIX
make
make install

