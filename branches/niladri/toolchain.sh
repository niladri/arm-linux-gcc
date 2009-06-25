#!/bin/sh

TOPLEVELDIR=`pwd`
TARGET=cortex

GCC=gcc-4.4.0
BINUTILS=binutils-2.19.1
GLIBC=glibc-2.9
GLIBCLT=glibc-linuxthreads-2.5
KERNEL=linux-2.6.30

wget -c http://ftp.gnu.org/gnu/gcc/$GCC/$GCC.tar.bz2 \
		http://ftp.gnu.org/gnu/binutils/$BINUTILS.tar.bz2 \
		http://ftp.gnu.org/gnu/glibc/$GLIBC.tar.bz2 \
		http://ftp.gnu.org/gnu/glibc/$GLIBCLT.tar.bz2 \
		http://www.kernel.org/pub/linux/kernel/v2.6/$KERNEL.tar.bz2 

mkdir -pv build/$BINUTILS
mkdir -pv build/$GCC
mkdir -pv build/$GLIBC
mkdir -pv $TARGET

if [ -d $BINUTILS ]
then
	echo "$BINUTILS exists"
else
	echo "Extracting $BINUTILS.tar.bz2"
	tar -jxf $BINUTILS.tar.bz2
fi

# Fix for BUG 7026
# http://sourceware.org/bugzilla/show_bug.cgi?id=7026
sed -i 's/as_bad (_(r/as_bad ("%s", _(r/' $BINUTILS/gas/config/tc-arm.c

cd build/$BINUTILS
if [ -f Makefile ]
then
	echo "Using old configuration. Delete build/$BINUTILS/Makefile to configure again"
else
	$TOPLEVELDIR/$BINUTILS/configure --target=arm-linux --prefix=$TOPLEVELDIR/$TARGET --disable-nls
fi
make
make install

cd $TOPLEVELDIR

if [ -d $KERNEL ]
then
	echo "$KERNEL exists"
else
	echo "Extracting $KERNEL.tar.bz2"
	tar -jxf $KERNEL.tar.bz2
fi

